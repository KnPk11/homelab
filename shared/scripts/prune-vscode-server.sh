#!/usr/bin/env bash
# =============================================================================
# prune_vscode_server.sh
# Version: 1.0
# Date: 2026-08-12
#
# Universal on-host cleaner for VS Code Remote-SSH residue under
# ~/.vscode-server (and /root + /home/* when run as root).
#
# Keeps:
#   - any running commit hash (active Remote-SSH / Cursor sessions)
#   - the newest entry from cli/servers/lru.json (if not already kept)
#   - --keep-extra N additional LRU builds (optional buffer)
#
# Prunes:
#   - Old server builds under cli/servers/ (Stable-* and Insiders-*)
#   - Old server builds under legacy bin/<commit>
#   - Standalone orphan code-* binaries
#   - Obsolete extension versions & marked .obsolete extensions (--dedupe-extensions)
#   - Old log folders under data/logs/ (--prune-logs [DAYS])
#   - Old file history snapshots under data/User/History/ (--prune-history [DAYS])
#   - Cached .vsix installer files and temporary directories (--prune-cache)
#
# Usage (run on the node itself, e.g. via cron or ansible):
#   ./prune_vscode_server.sh              # dry-run
#   ./prune_vscode_server.sh --apply
#   ./prune_vscode_server.sh --apply --all
# =============================================================================
set -euo pipefail

APPLY=0
KEEP_EXTRA=0
DEDUPE_EXT=0
PRUNE_LOGS_DAYS=-1
PRUNE_HISTORY_DAYS=-1
PRUNE_CACHE=0
INCLUDE_ROOT=1
INCLUDE_HOME=1

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  --apply                 Actually delete (default: dry-run)
  --keep-extra N          Keep N extra LRU builds beyond running+newest (default 0)
  --dedupe-extensions     Remove older semver installs of the same extension & .obsolete
  --prune-logs [DAYS]     Purge log session folders older than N days (default 14)
  --prune-history [DAYS]  Purge file history snapshots older than N days (default 30)
  --prune-cache           Clear cached VSIX files and temporary directories
  --all                   Enable --dedupe-extensions, --prune-logs 14, --prune-history 30, --prune-cache
  --no-root               Skip /root/.vscode-server
  --no-home               Skip /home/*/.vscode-server
  -h, --help              This help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --keep-extra)
      if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --keep-extra requires a non-negative integer argument." >&2
        exit 1
      fi
      KEEP_EXTRA="$2"; shift 2 ;;
    --dedupe-extensions) DEDUPE_EXT=1; shift ;;
    --prune-logs)
      if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
        PRUNE_LOGS_DAYS="$2"; shift 2
      else
        PRUNE_LOGS_DAYS=14; shift
      fi ;;
    --prune-history)
      if [[ -n "${2:-}" && "$2" =~ ^[0-9]+$ ]]; then
        PRUNE_HISTORY_DAYS="$2"; shift 2
      else
        PRUNE_HISTORY_DAYS=30; shift
      fi ;;
    --prune-cache) PRUNE_CACHE=1; shift ;;
    --all)
      DEDUPE_EXT=1
      PRUNE_LOGS_DAYS=14
      PRUNE_HISTORY_DAYS=30
      PRUNE_CACHE=1
      shift ;;
    --no-root) INCLUDE_ROOT=0; shift ;;
    --no-home) INCLUDE_HOME=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

export PRUNE_APPLY="$APPLY"
export PRUNE_KEEP_EXTRA="$KEEP_EXTRA"
export PRUNE_DEDUPE_EXT="$DEDUPE_EXT"
export PRUNE_LOGS_DAYS="$PRUNE_LOGS_DAYS"
export PRUNE_HISTORY_DAYS="$PRUNE_HISTORY_DAYS"
export PRUNE_CACHE="$PRUNE_CACHE"
export PRUNE_INCLUDE_ROOT="$INCLUDE_ROOT"
export PRUNE_INCLUDE_HOME="$INCLUDE_HOME"

python3 - <<'PY'
import json, os, re, shutil, sys, time
from pathlib import Path

apply = os.environ.get("PRUNE_APPLY", "0") == "1"
keep_extra = int(os.environ.get("PRUNE_KEEP_EXTRA", "0"))
dedupe_ext = os.environ.get("PRUNE_DEDUPE_EXT", "0") == "1"
prune_logs_days = int(os.environ.get("PRUNE_LOGS_DAYS", "-1"))
prune_history_days = int(os.environ.get("PRUNE_HISTORY_DAYS", "-1"))
prune_cache = os.environ.get("PRUNE_CACHE", "0") == "1"
include_root = os.environ.get("PRUNE_INCLUDE_ROOT", "1") == "1"
include_home = os.environ.get("PRUNE_INCLUDE_HOME", "1") == "1"

def du_bytes(p: Path) -> int:
    total = 0
    if not p.exists():
        return 0
    for root, _dirs, files in os.walk(p, followlinks=False):
        for name in files:
            try:
                total += (Path(root) / name).stat().st_size
            except OSError:
                pass
    return total

def fmt(n: int) -> str:
    x = float(n)
    for u in ("B", "K", "M", "G", "T"):
        if abs(x) < 1024 or u == "T":
            return f"{int(x)}B" if u == "B" else f"{x:.1f}{u}"
        x /= 1024.0
    return f"{x:.1f}T"

def running_commits() -> set[str]:
    found: set[str] = set()
    for ent in Path("/proc").iterdir():
        if not ent.name.isdigit():
            continue
        try:
            raw = (ent / "cmdline").read_bytes()
        except OSError:
            continue
        cmd = raw.replace(b"\0", b" ").decode("utf-8", "ignore")
        if not cmd:
            continue
        if "python" in cmd.split(" ", 1)[0] and "prune_vscode_server" in cmd:
            continue
        if any(k in cmd for k in ("vscode-server", "cursor-server", "code-server", "vscode")):
            for m in re.finditer(r"([0-9a-f]{40})", cmd):
                found.add(m.group(1))
    return found

def bases() -> list[Path]:
    out: list[Path] = []
    if include_root:
        p = Path("/root/.vscode-server")
        if p.is_dir():
            out.append(p)
    home = Path.home() / ".vscode-server"
    if home.is_dir() and home not in out:
        out.append(home)
    if include_home:
        home_root = Path("/home")
        if home_root.is_dir():
            for user_home in sorted(home_root.iterdir()):
                p = user_home / ".vscode-server"
                if p.is_dir() and p not in out:
                    out.append(p)
    return out

def prune_servers(base: Path, running: set[str]) -> int:
    freed = 0
    keep: set[str] = set()
    # 1. Modern CLI servers: base / cli / servers
    servers_dir = base / "cli" / "servers"
    if servers_dir.is_dir():
        versions = [
            d for d in servers_dir.iterdir()
            if d.is_dir() and (d.name.startswith("Stable-") or d.name.startswith("Insiders-"))
        ]
        lru: list[str] = []
        lru_path = servers_dir / "lru.json"
        if lru_path.is_file():
            try:
                data = json.loads(lru_path.read_text())
                if isinstance(data, list):
                    for item in data:
                        if isinstance(item, str):
                            lru.append(item)
                        elif isinstance(item, dict) and "id" in item:
                            lru.append(str(item["id"]))
            except (json.JSONDecodeError, OSError) as e:
                print(f"  ! lru.json read error: {e}")

        for h in running:
            for prefix in ("Stable-", "Insiders-"):
                if (servers_dir / f"{prefix}{h}").is_dir():
                    keep.add(f"{prefix}{h}")

        for entry in lru:
            if (servers_dir / entry).is_dir():
                keep.add(entry)
                break

        extras = 0
        for entry in lru:
            if entry in keep or not (servers_dir / entry).is_dir():
                continue
            if extras >= keep_extra:
                break
            keep.add(entry)
            extras += 1

        if not keep and versions:
            keep.add(max(versions, key=lambda p: p.stat().st_mtime).name)

        if versions:
            print(f"  [CLI Servers] keeping: {sorted(keep)}")

        for v in versions:
            if v.name in keep:
                continue
            size = du_bytes(v)
            if apply:
                try:
                    shutil.rmtree(v)
                    print(f"  rm  cli/servers/{v.name} ({fmt(size)})")
                    freed += size
                except OSError as e:
                    print(f"  FAIL cli/servers/{v.name}: {e}")
            else:
                print(f"  would_rm cli/servers/{v.name} ({fmt(size)})")
                freed += size

        if apply and lru_path.exists():
            new_lru = [x for x in lru if x in keep]
            for k in sorted(keep):
                if k not in new_lru:
                    new_lru.append(k)
            try:
                lru_path.write_text(json.dumps(new_lru))
                st = base.stat()
                os.chown(lru_path, st.st_uid, st.st_gid)
            except OSError as e:
                print(f"  ! lru rewrite error: {e}")

    # 2. Legacy server directory: base / bin
    bin_dir = base / "bin"
    if bin_dir.is_dir():
        legacy_versions = [
            d for d in bin_dir.iterdir()
            if d.is_dir() and re.fullmatch(r"[0-9a-f]{40}(?:-web)?", d.name)
        ]
        for lv in legacy_versions:
            commit = lv.name.removesuffix("-web")
            if commit in running:
                print(f"  [Legacy bin] keeping active session {lv.name}")
                continue
            size = du_bytes(lv)
            if apply:
                try:
                    shutil.rmtree(lv)
                    print(f"  rm  bin/{lv.name} ({fmt(size)})")
                    freed += size
                except OSError as e:
                    print(f"  FAIL bin/{lv.name}: {e}")
            else:
                print(f"  would_rm bin/{lv.name} ({fmt(size)})")
                freed += size

    # 3. Orphan top-level code-* binaries
    keep_hashes = {
        k.removeprefix("Stable-").removeprefix("Insiders-") for k in keep
    } | set(running)
    for code in base.glob("code-*"):
        if not code.is_file():
            continue
        m = re.fullmatch(r"code-([0-9a-f]{40})", code.name)
        if not m:
            continue
        if m.group(1) in keep_hashes:
            continue
        size = code.stat().st_size
        if apply:
            try:
                code.unlink()
                print(f"  rm  {code.name} ({fmt(size)})")
                freed += size
            except OSError as e:
                print(f"  FAIL {code.name}: {e}")
        else:
            print(f"  would_rm {code.name} ({fmt(size)})")
            freed += size

    return freed

def prune_extensions(ext_dir: Path, dedupe: bool) -> int:
    if not ext_dir.is_dir():
        return 0
    freed = 0

    obsolete_file = ext_dir / ".obsolete"
    if obsolete_file.is_file():
        try:
            obs_data = json.loads(obsolete_file.read_text())
            if isinstance(obs_data, dict):
                for folder_name in obs_data.keys():
                    target = ext_dir / folder_name
                    if target.is_dir():
                        size = du_bytes(target)
                        if apply:
                            try:
                                shutil.rmtree(target)
                                print(f"  rm  obsolete extension {target.name} ({fmt(size)})")
                                freed += size
                            except OSError as e:
                                print(f"  FAIL obsolete {target.name}: {e}")
                        else:
                            print(f"  would_rm obsolete extension {target.name} ({fmt(size)})")
                            freed += size
        except (json.JSONDecodeError, OSError) as e:
            print(f"  ! .obsolete parse error: {e}")

    for tmp in ext_dir.glob("*.tmp"):
        size = du_bytes(tmp) if tmp.is_dir() else tmp.stat().st_size
        if apply:
            try:
                if tmp.is_dir():
                    shutil.rmtree(tmp)
                else:
                    tmp.unlink()
                print(f"  rm  tmp extension {tmp.name} ({fmt(size)})")
                freed += size
            except OSError as e:
                print(f"  FAIL tmp extension {tmp.name}: {e}")
        else:
            print(f"  would_rm tmp extension {tmp.name} ({fmt(size)})")
            freed += size

    if dedupe:
        semver = re.compile(r"^(?P<name>.+)-(?P<ver>\d+\.\d+\.\d+)(?:$|-)")
        groups: dict[str, list[tuple[tuple[int, ...], Path]]] = {}
        for d in ext_dir.iterdir():
            if not d.is_dir():
                continue
            m = semver.match(d.name)
            if not m:
                continue
            try:
                ver_tuple = tuple(int(x) for x in m.group("ver").split("."))
            except ValueError:
                continue
            groups.setdefault(m.group("name"), []).append((ver_tuple, d))

        for name, items in groups.items():
            if len(items) < 2:
                continue
            items_sorted = sorted(items, key=lambda x: x[0], reverse=True)
            for _ver, path in items_sorted[1:]:
                size = du_bytes(path)
                if apply:
                    try:
                        shutil.rmtree(path)
                        print(f"  rm  older extension {path.name} ({fmt(size)})")
                        freed += size
                    except OSError as e:
                        print(f"  FAIL extension {path.name}: {e}")
                else:
                    print(f"  would_rm older extension {path.name} ({fmt(size)})")
                    freed += size

    return freed

def prune_logs(logs_dir: Path, days: int) -> int:
    if not logs_dir.is_dir() or days < 0:
        return 0
    cutoff = time.time() - (days * 86400)
    freed = 0
    for entry in logs_dir.iterdir():
        if entry.is_dir():
            try:
                mtime = entry.stat().st_mtime
            except OSError:
                continue
            if mtime < cutoff:
                size = du_bytes(entry)
                if apply:
                    try:
                        shutil.rmtree(entry)
                        print(f"  rm  old log folder {entry.name} ({fmt(size)})")
                        freed += size
                    except OSError as e:
                        print(f"  FAIL log folder {entry.name}: {e}")
                else:
                    print(f"  would_rm old log folder {entry.name} ({fmt(size)})")
                    freed += size
    return freed

def prune_history(history_dir: Path, days: int) -> int:
    if not history_dir.is_dir() or days < 0:
        return 0
    cutoff = time.time() - (days * 86400)
    freed = 0
    for folder in history_dir.iterdir():
        if not folder.is_dir():
            continue
        for file in folder.iterdir():
            if file.name == "entries.json":
                continue
            try:
                mtime = file.stat().st_mtime
            except OSError:
                continue
            if mtime < cutoff:
                size = file.stat().st_size
                if apply:
                    try:
                        file.unlink()
                        freed += size
                    except OSError:
                        pass
                else:
                    freed += size
    if freed > 0:
        msg = "rm" if apply else "would_rm"
        print(f"  {msg} history snapshots older than {days}d ({fmt(freed)})")
    return freed

def prune_cache_dirs(base: Path) -> int:
    if not prune_cache:
        return 0
    freed = 0
    cache_vsix = base / "data" / "CachedExtensionVSIXs"
    if cache_vsix.is_dir():
        size = du_bytes(cache_vsix)
        if size > 0:
            if apply:
                for f in cache_vsix.iterdir():
                    try:
                        if f.is_dir():
                            shutil.rmtree(f)
                        else:
                            f.unlink()
                    except OSError:
                        pass
                print(f"  cleared CachedExtensionVSIXs ({fmt(size)})")
                freed += size
            else:
                print(f"  would_clear CachedExtensionVSIXs ({fmt(size)})")
                freed += size
    return freed

def prune_tree(base: Path, running: set[str]) -> tuple[int, int]:
    before = du_bytes(base)
    print(f"\n=== {base} ({fmt(before)}) ===")

    freed = 0
    freed += prune_servers(base, running)
    freed += prune_extensions(base / "extensions", dedupe_ext)
    freed += prune_logs(base / "data" / "logs", prune_logs_days)
    freed += prune_history(base / "data" / "User" / "History", prune_history_days)
    freed += prune_cache_dirs(base)

    after = du_bytes(base) if apply else before - freed
    print(f"  -> ~{fmt(after)} (free ~{fmt(freed)})")
    return before, freed

mode = "APPLY" if apply else "DRY-RUN"
print(f"[prune-vscode] mode={mode} keep_extra={keep_extra} dedupe_ext={dedupe_ext} logs_days={prune_logs_days} history_days={prune_history_days} cache={prune_cache}")
running = running_commits()
print(f"[prune-vscode] running_commits={sorted(running) or ['(none)']}")

trees = bases()
if not trees:
    print("No ~/.vscode-server trees found.")
    sys.exit(0)

total_freed = 0
for base in trees:
    _before, freed = prune_tree(base, running)
    total_freed += freed

print(f"\n[prune-vscode] total free ~{fmt(total_freed)}")
if not apply:
    print("[prune-vscode] dry-run only — re-run with --apply to delete")
PY
