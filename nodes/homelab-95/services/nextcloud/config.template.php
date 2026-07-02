<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'overwrite.cli.url' => 'https://${NC_DOMAIN}',
  'overwritewebroot' => '/',
  'overwritehost' => '${NC_DOMAIN}',
  'overwriteprotocol' => 'https',
  'trusted_proxies' => 
  array (
    0 => '172.27.0.0/16',
    2 => '192.168.16.5',
  ),
  'forwarded_for_headers' => 
  array (
    0 => 'HTTP_X_FORWARDED_FOR',
  ),
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'maintenance_window_start' => 3,
  'trusted_domains' => 
  array (
    0 => 'localhost',
    1 => '192.168.50.95',
    2 => '${NC_DOMAIN}',
  ),
  'apps_paths' => 
  array (
    0 => 
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 => 
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'upgrade.disable-web' => true,
  'instanceid' => '${NC_INSTANCEID}',
  'passwordsalt' => '${NC_PASSWORDSALT}',
  'secret' => '${NC_SECRET}',
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '32.0.3.2',
  'dbname' => 'nextcloud',
  'dbhost' => 'nextcloud_db',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => '${NC_DBPASSWORD}',
  'installed' => true,
  'loglevel' => 2,
  'maintenance' => false,
  'memories.db.triggers.fcu' => true,
  'memories.exiftool' => '/var/www/html/custom_apps/memories/bin-ext/exiftool-x86_64-glibc',
  'memories.vod.path' => '/var/www/html/custom_apps/memories/bin-ext/go-vod-x86_64',
  'app_install_overwrite' => 
  array (
    0 => 'secsignid',
  ),
  'redis' => 
  array (
    'host' => 'nextcloud_redis',
    'port' => '6379',
  ),
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'talk.signaling_url' => 'http://nextcloud_talk_hpb:8081',
  'talk.signaling_host' => '${TALK_HOST}',
  'config_is_read_only' => true,
);