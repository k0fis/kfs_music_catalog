# kfs_music_catalog

Catalog and search tool for media libraries. Two parts:

1. **Client (macOS)** - bash + fzf for local fuzzy search
2. **Server (k-server)** - web-based fuzzy search via browser

## Client - local fzf search

### Install

```bash
git clone https://github.com/k0fis/kfs_music_catalog.git
cd kfs_music_catalog

# non-interactive
./install.sh /Volumes/music ab ~/bin "Audiobooks*"

# interactive
./install.sh
```

### Usage

```bash
scan_ab        # reindex
find_ab        # fuzzy search
find_ab "King" # pre-filtered search
```

## Server - web catalog

Web-based fuzzy search for k-server. Indexes all media from `/media/storage/`.

### Categories (auto-indexed)
- audiobooks, music, comix, books, pohadky, movies, movies_doc

### Manual catalogs
Files in `/opt/catalog/manual/*.catalog`:
```
# Format: name|note
Blade Runner 2049|4K UHD
Interstellar|Blu-ray
```

### Install / Update

```bash
# First install (or update to latest release)
curl -sL https://raw.githubusercontent.com/k0fis/kfs_music_catalog/main/server/server-install.sh | bash

# Or download and run manually
wget https://raw.githubusercontent.com/k0fis/kfs_music_catalog/main/server/server-install.sh
bash server-install.sh
```

### Manual reindex

```bash
/opt/catalog/indexer.sh /var/www/html/catalog
```

### Structure on server
```
/opt/catalog/
  indexer.sh          - index generator (cron every 6h)
  manual/             - manual catalogs (*.catalog)
  VERSION             - installed version
  last-index.log      - last indexer output

/var/www/html/catalog/
  index.html          - web frontend (fuse.js)
  data.json           - generated index
```

## Release

Tag a version to create a release:
```bash
git tag v1.0.0
git push origin v1.0.0
```
GitHub Actions builds `server.tar.gz` and attaches it to the release.
