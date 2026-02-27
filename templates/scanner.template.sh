#!/bin/bash

ROOT="{{BASE_FOLDER}}"
OUT="{{BIN_DIR}}/{{NAME}}.index"

> "$OUT"

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

                echo "$author - $book|$d2" >> "$OUT"
            done
        else
            echo "$name|$d1" >> "$OUT"
        fi
    done

done

echo "Indexed -> $OUT"