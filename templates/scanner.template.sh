#!/bin/bash

ROOT="{{BASE_FOLDER}}"
OUT="{{BIN_DIR}}/{{NAME}}.index"

TMP=$(mktemp)

scan() {
  find "$ROOT" -maxdepth 1 -type d -iname "{{DIR_PREFIX}}" | while read abdir
  do
      # Autor - Audiokniha
      find "$abdir" -mindepth 1 -maxdepth 1 -type d | while read d1
      do
          name=$(basename "$d1")

          # pokud obsahuje další podsložky -> Autor/Audiokniha
          sub=$(find "$d1" -mindepth 1 -maxdepth 1 -type d | head -n1)

          if [ -n "$sub" ]; then
              find "$d1" -mindepth 1 -maxdepth 1 -type d | while read d2
              do
                  author=$(basename "$d1")
                  book=$(basename "$d2")

                  echo "$author - $book|$d2"
              done
          else
              echo "$name|$d1"
          fi
      done

  done

}

echo "Scanning...$ROOT / {{DIR_PREFIX}}"

scan > "$TMP"

sort -u "$TMP" -o "$TMP"

if [ -f "$OUT" ]; then

    echo "Diffing..."

    added=$(comm -13 "$OUT" "$TMP" | wc -l | tr -d ' ')
    removed=$(comm -23 "$OUT" "$TMP" | wc -l | tr -d ' ')

    echo "Added   : $added"
    echo "Removed : $removed"

fi

mv "$TMP" "$OUT"

echo "Indexed -> $OUT"

awk -F'|' '{print $1}' "${OUT}" | sort | uniq -d | while read dup
do
    echo "Duplicate: $dup"
    # grep -F "$dup|" audiobooks.index
done