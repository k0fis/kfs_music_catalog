#!/bin/bash
# k-server catalog indexer
# Generuje data.json pro webovy katalog
# Spousteni: bash indexer.sh [vystupni-adresar]
#
# Cron: 7 */6 * * * /opt/catalog/indexer.sh /var/www/html/catalog

STORAGE="${CATALOG_STORAGE:-/media/storage}"
MANUAL_DIR="${CATALOG_MANUAL:-/opt/catalog/manual}"
VERSION_FILE="${CATALOG_VERSION:-/opt/catalog/VERSION}"
OUT_DIR="${1:-/var/www/html/catalog}"

mkdir -p "$OUT_DIR"

# --- Pomocne funkce ---

json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g'
}

emit_item() {
    local name="$1" category="$2" path="$3" link="$4"
    name=$(echo "$name" | json_escape)
    path=$(echo "$path" | json_escape)
    link=$(echo "$link" | json_escape)
    echo "{\"n\":\"$name\",\"c\":\"$category\",\"p\":\"$path\",\"l\":\"$link\"}"
}

smb_link() {
    echo "$1" | sed "s|^$STORAGE/|smb://k-server.local/Share/|"
}

# KAP deep links — SHA-1 hash matching music-indexer.py / audiobooks-indexer.py
kap_lower() {
    python3 -c "import sys; print(sys.argv[1].strip().lower(), end='')" "$1"
}

kap_artist_link() {
    local mode="$1" name="$2"
    local lower=$(kap_lower "$name")
    local hash=$(printf '%s' "$lower" | sha1sum | cut -c1-10)
    printf '/kap/?mode=%s#artist/a-%s' "$mode" "$hash"
}

kap_album_link() {
    local artist="$1" album="$2"
    local a_lower=$(kap_lower "$artist")
    local b_lower=$(kap_lower "$album")
    local a_hash=$(printf '%s' "$a_lower" | sha1sum | cut -c1-10)
    local ab_hash=$(printf '%s/%s' "$a_lower" "$b_lower" | sha1sum | cut -c1-10)
    printf '/kap/?mode=audiobooks#album/a-%s/al-%s' "$a_hash" "$ab_hash"
}

# --- Sber polozek ---

TMPFILE=$(mktemp)

# 1. Audiobooks (Autor/Kniha, vice kategorii Audiobooks* + Fun + Lenka)
echo "Indexuji audiobooks..."
for ab_dir in "$STORAGE"/music/Audiobooks* "$STORAGE"/music/Fun "$STORAGE"/music/Lenka; do
    [ -d "$ab_dir" ] || continue
    for author_dir in "$ab_dir"/*/; do
        [ -d "$author_dir" ] || continue
        author=$(basename "$author_dir")
        subdirs=$(find "$author_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [ "$subdirs" -gt 0 ]; then
            for book_dir in "$author_dir"/*/; do
                [ -d "$book_dir" ] || continue
                book=$(basename "$book_dir")
                emit_item "$author - $book" "audiobooks" "$book_dir" "$(kap_album_link "$author" "$book")" >> "$TMPFILE"
            done
        else
            emit_item "$author" "audiobooks" "$author_dir" "$(kap_artist_link audiobooks "$author")" >> "$TMPFILE"
        fi
    done
done

# 2. Music (Interpret, vice kategorii Music*)
echo "Indexuji music..."
for music_dir in "$STORAGE"/music/Music*; do
    [ -d "$music_dir" ] || continue
    for artist_dir in "$music_dir"/*/; do
        [ -d "$artist_dir" ] || continue
        artist=$(basename "$artist_dir")
        emit_item "$artist" "music" "$artist_dir" "$(kap_artist_link music "$artist")" >> "$TMPFILE"
    done
done

# 3. Comix (preskoc pokud existuje manualni comix.catalog)
if [ -f "$MANUAL_DIR/comix.catalog" ]; then
    echo "Comix: pouzivam manualni comix.catalog, preskakuji auto-index"
else
    echo "Indexuji comix..."
    for serie_dir in "$STORAGE"/comix/*/; do
        [ -d "$serie_dir" ] || continue
        serie=$(basename "$serie_dir")
        emit_item "$serie" "comix" "$serie_dir" "/comix/" >> "$TMPFILE"
        find "$serie_dir" -maxdepth 1 \( -name "*.cbz" -o -name "*.cbr" -o -name "*.pdf" \) -print0 2>/dev/null | \
        while IFS= read -r -d '' f; do
            fname=$(basename "$f" | sed 's/\.\(cbz\|cbr\|pdf\)$//')
            emit_item "$fname" "comix" "$f" "/comix/" >> "$TMPFILE"
        done
    done
fi

# 4. Books (preskoc pokud existuje manualni books.catalog)
if [ -f "$MANUAL_DIR/books.catalog" ]; then
    echo "Books: pouzivam manualni books.catalog, preskakuji auto-index"
else
    echo "Indexuji books..."
    if [ -d "$STORAGE/books/books" ]; then
        for author_dir in "$STORAGE"/books/books/*/; do
            [ -d "$author_dir" ] || continue
            author=$(basename "$author_dir")
            for book_dir in "$author_dir"/*/; do
                [ -d "$book_dir" ] || continue
                book_raw=$(basename "$book_dir")
                book=$(echo "$book_raw" | sed 's/ ([0-9]*)$//')
                book_id=$(echo "$book_raw" | sed -n 's/.* (\([0-9]*\))$/\1/p')
                if [ -n "$book_id" ]; then
                    emit_item "$author - $book" "books" "$book_dir" "/books/#$book_id" >> "$TMPFILE"
                else
                    emit_item "$author - $book" "books" "$book_dir" "/books/" >> "$TMPFILE"
                fi
            done
        done
    fi
fi

# 5. Pohadky (flat)
echo "Indexuji pohadky..."
for dir in "$STORAGE"/pohadky/*/; do
    [ -d "$dir" ] || continue
    emit_item "$(basename "$dir")" "pohadky" "$dir" "$(smb_link "$dir")" >> "$TMPFILE"
done

# 6. Filmy (flat)
echo "Indexuji movies..."
for dir in "$STORAGE"/movies/*/; do
    [ -d "$dir" ] || continue
    emit_item "$(basename "$dir")" "movies" "$dir" "$(smb_link "$dir")" >> "$TMPFILE"
done

# 7. Dokumentarni filmy (flat)
echo "Indexuji movies_doc..."
for dir in "$STORAGE"/movies_doc/*/; do
    [ -d "$dir" ] || continue
    emit_item "$(basename "$dir")" "movies_doc" "$dir" "$(smb_link "$dir")" >> "$TMPFILE"
done

# 8. Manualni katalogy
echo "Indexuji manualni katalogy..."
if [ -d "$MANUAL_DIR" ]; then
    for catalog_file in "$MANUAL_DIR"/*.catalog; do
        [ -f "$catalog_file" ] || continue
        category=$(basename "$catalog_file" .catalog)
        while IFS='|' read -r name note; do
            [ -z "$name" ] && continue
            [[ "$name" == \#* ]] && continue
            link=""
            display="$name"
            if [[ "$note" == /* || "$note" == http* ]]; then
                link="$note"
            elif [ -n "$note" ]; then
                display="$name ($note)"
            fi
            emit_item "$display" "$category" "" "$link" >> "$TMPFILE"
        done < "$catalog_file"
    done
fi

# 9. Inventory (z PostgreSQL)
echo "Indexuji inventory..."
psql -U kofis -d inventory -t -A -F'|' -c \
    "SELECT name, brand, model, id FROM devices ORDER BY name" 2>/dev/null | \
while IFS='|' read -r name brand model dev_id; do
    [ -z "$name" ] && continue
    display="$name"
    if [ -n "$brand" ] && [ -n "$model" ]; then
        display="$brand $model"
        [ "$name" != "$brand $model" ] && display="$name ($brand $model)"
    fi
    emit_item "$display" "inventory" "" "/inventory/#$dev_id" >> "$TMPFILE"
done

# --- Vystup ---

COUNT=$(wc -l < "$TMPFILE" | tr -d ' ')
echo "Celkem $COUNT polozek"

{
    echo "{\"generated\":\"$(date -Iseconds)\",\"count\":$COUNT,\"items\":["
    # Spoj radky carkou, posledni bez
    sed '$ ! s/$/,/' "$TMPFILE"
    echo "]}"
} > "$OUT_DIR/data.json"

rm -f "$TMPFILE"

# Zkopiruj VERSION do web adresare
[ -f "$VERSION_FILE" ] && cp "$VERSION_FILE" "$OUT_DIR/VERSION"

echo "Zapsano do $OUT_DIR/data.json"
