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

# --- Sber polozek ---

TMPFILE=$(mktemp)

# 1. Audiobooks (Autor/Kniha, vice kategorii Audiobooks*)
echo "Indexuji audiobooks..."
for ab_dir in "$STORAGE"/music/Audiobooks*; do
    [ -d "$ab_dir" ] || continue
    for author_dir in "$ab_dir"/*/; do
        [ -d "$author_dir" ] || continue
        author=$(basename "$author_dir")
        subdirs=$(find "$author_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [ "$subdirs" -gt 0 ]; then
            for book_dir in "$author_dir"/*/; do
                [ -d "$book_dir" ] || continue
                book=$(basename "$book_dir")
                emit_item "$author - $book" "audiobooks" "$book_dir" "$(smb_link "$book_dir")" >> "$TMPFILE"
            done
        else
            emit_item "$author" "audiobooks" "$author_dir" "$(smb_link "$author_dir")" >> "$TMPFILE"
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
        emit_item "$artist" "music" "$artist_dir" "$(smb_link "$artist_dir")" >> "$TMPFILE"
    done
done

# 3. Comix (Serie + soubory)
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

# 4. Books (Calibre: Autor/Kniha)
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
                emit_item "$author - $book" "books" "$book_dir" "/books/book/$book_id" >> "$TMPFILE"
            else
                emit_item "$author - $book" "books" "$book_dir" "/books/" >> "$TMPFILE"
            fi
        done
    done
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
