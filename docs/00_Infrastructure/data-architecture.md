> [!NOTE]
> **Tags:** #Infrastructure #Architecture #Storage #DataManagement

# Data Architecture & Directory Structure

This document defines the high-level organization of data across the homelab, ensuring consistency for SMB shares, media services, and backup routines.

---

## Global Directory Map

The following structure is used to organize data across the primary storage pool.

```text
# App-specific metadata (configs, databases, local cache).
└── Apps/
    └── photoprism/
    └── anytype/

# Sensitive and private documents (served via SMB & VPN only).
└── Private/
    ├── Documents/
    ├── Photos/
    ├── Video/
    └── Audio/

# Public/Shared media for Jellyfin & Symfonium.
└── Media/
    ├── Music/
    └── Videos/

# Ingest zone for new content.
└── Downloads/
    ├── Torrents/
    └── Youtube/

# Collaboration and public-facing shares.
└── Shared/
    ├── Users/
    │   ├── [USER-A]/
    │   ├── [USER-B]/
    │   └── Public/
    │   └── Recycled
    └── Content/
        ├── Public gallery/
        └── Temporary share/

# Encrypted shares for sensitive remote access (e.g., Nextcloud).
└── Shared_enc/
    ├── Photos_[USER-A]/
    └── Documents_[USER-B]/
```

---

## Usage Principles

1. **Separation of Concerns**: Apps should store their persistent configuration in `/Apps`, keeping the `/Media` and `/Private` folders clean for data only.
2. **Access Control**: `/Private` should never be exposed to public-facing services (e.g., Nextcloud or external galleries) without additional encryption layers.
3. **Mounting Strategy**: These top-level directories are typically mounted under `/mnt/pool` using a combination of LVM, ZFS, or MergerFS.
