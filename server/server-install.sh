#!/bin/bash
# Instalace/update weboveho katalogu na k-server
# Stahne posledni release z GitHubu a nasadi
#
# Pouziti:
#   bash server-install.sh          # instalace + update
#   bash server-install.sh --cron   # jen nastavi cron (bez stahovani)

set -e

REPO="k0fis/kfs_music_catalog"
INSTALL_DIR="/opt/catalog"
WEB_DIR="/var/www/html/catalog"
MANUAL_DIR="$INSTALL_DIR/manual"

# --- Funkce ---

get_latest_version() {
    curl -sL "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name"' | cut -d'"' -f4
}

get_download_url() {
    curl -sL "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"browser_download_url".*server\.tar\.gz' | cut -d'"' -f4
}

get_installed_version() {
    [ -f "$INSTALL_DIR/VERSION" ] && cat "$INSTALL_DIR/VERSION" || echo "none"
}

setup_cron() {
    local CRON_LINE="7 */6 * * * $INSTALL_DIR/indexer.sh $WEB_DIR > $INSTALL_DIR/last-index.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "indexer.sh"; echo "$CRON_LINE") | crontab -
    echo "Cron nastaven: kazdych 6 hodin"
}

# --- Main ---

if [ "$1" = "--cron" ]; then
    setup_cron
    exit 0
fi

echo "=== k-server catalog installer ==="
echo ""

INSTALLED=$(get_installed_version)
echo "Nainstalovana verze: $INSTALLED"

echo "Zjistuji posledni verzi..."
LATEST=$(get_latest_version)

if [ -z "$LATEST" ]; then
    echo "Chyba: nepodarilo se zjistit posledni verzi"
    exit 1
fi

echo "Posledni verze: $LATEST"

if [ "$INSTALLED" = "$LATEST" ]; then
    echo "Uz je aktualni."
    exit 0
fi

URL=$(get_download_url)
if [ -z "$URL" ]; then
    echo "Chyba: nepodarilo se zjistit URL artefaktu"
    exit 1
fi

echo "Stahuji: $URL"
TMP=$(mktemp -d)
curl -sL "$URL" -o "$TMP/server.tar.gz"
tar xzf "$TMP/server.tar.gz" -C "$TMP"

echo "Instaluji..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$WEB_DIR"
mkdir -p "$MANUAL_DIR"

# Aktualizuj indexer
cp "$TMP/server/indexer.sh" "$INSTALL_DIR/indexer.sh"
chmod +x "$INSTALL_DIR/indexer.sh"

# Aktualizuj web
cp "$TMP/server/web/index.html" "$WEB_DIR/index.html"

# Manualni katalogy - jen priklad, neprepise existujici
for example in "$TMP"/server/manual/*.catalog.example; do
    [ -f "$example" ] || continue
    target="$MANUAL_DIR/$(basename "$example" .example)"
    if [ ! -f "$target" ]; then
        cp "$example" "$target"
        echo "  Vytvoren: $target"
    fi
done

# Zapis verzi
echo "$LATEST" > "$INSTALL_DIR/VERSION"

# Cron
setup_cron

# Prvni indexace (pokud jeste neni data.json)
if [ ! -f "$WEB_DIR/data.json" ]; then
    echo "Spoustim prvni indexaci..."
    bash "$INSTALL_DIR/indexer.sh" "$WEB_DIR"
fi

# Cleanup
rm -rf "$TMP"

echo ""
echo "=== Hotovo ==="
echo "Verze: $LATEST"
echo "Web: https://k-server.local/catalog/"
echo "Manualni katalogy: $MANUAL_DIR/"
echo "Reindexace: $INSTALL_DIR/indexer.sh $WEB_DIR"
