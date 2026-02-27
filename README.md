# kfs_music_catalog

`git clone https://github.com/k0fis/kfs_music_catalog.git`

## install non-interactive:

`./install.sh /Volumes/music ab ~/bin "Audiobooks*"`

```bash
./install.sh ~/arxive/books books ~/arxive/catalog books
```

## install with interactive

``` bash
./install.sh
```

---

## scan folders

``` bash
#!/bin/bash

ROOT="/Volumes/music"
OUT="$HOME/arxive/catalog/audiobooks.index"

> "$OUT"

find "$ROOT" -maxdepth 1 -type d -iname "Audiobooks*" | while read abdir
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
```

## find

``` bash
#!/bin/bash

INDEX="$HOME/arxive/catalog/audiobooks.index"

sel=$(cut -d'|' -f1 "$INDEX" | fzf --query $1 --select-1  --exit-0)

[ -z "$sel" ] && exit

path=$(grep "^$sel|" "$INDEX" | head -n1 | cut -d'|' -f2)

open "$path"
```
