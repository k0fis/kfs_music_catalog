#!/usr/bin/env bash
set -e

if [ $# -eq 4 ]; then
    BASE_FOLDER="$1"
    NAME="$2"
    BIN_DIR="$3"
    DIR_PREFIX="$4"
else
    # interactive fallback
    echo "Interactive installer (fallback because missing parameters)"
    echo ""

    ask () {
        local prompt="$1"
        local default="$2"
        read -p "$prompt [$default]: " value
        if [ -z "$value" ]; then
            value="$default"
        fi
        echo "$value"
    }

    BASE_FOLDER=$(ask "Base folder" "/Volumes/music")
    NAME=$(ask "Short name (example ab)" "ab")
    BIN_DIR=$(ask "Local bin folder" "$HOME/bin")
    DIR_PREFIX=$(ask "Subfolder under Base" "Audiobooks*")

    echo ""
    echo "Summary:"
    echo "Folder    : $BASE_FOLDER"
    echo "Subfolder : $DIR_PREFIX"
    echo "Name      : $NAME"
    echo "Bin       : $BIN_DIR"

    read -p "Continue? (y/N): " ok
    [[ "$ok" != "y" && "$ok" != "Y" ]] && exit 0
fi

mkdir -p "$BIN_DIR"

create_script () {

    template="$1"
    output="$2"

    sed \
        -e "s|{{BASE_FOLDER}}|$BASE_FOLDER|g" \
        -e "s|{{NAME}}|$NAME|g" \
        -e "s|{{DIR_PREFIX}}|$DIR_PREFIX|g" \
        -e "s|{{BIN_DIR}}|$BIN_DIR|g" \
        "$template" > "$output"

    chmod +x "$output"
}

create_script \
 templates/scanner.template.sh \
 "$BIN_DIR/scanner_${NAME}.sh"

create_script \
 templates/find.template.sh \
 "$BIN_DIR/find_${NAME}.sh"

echo ""
echo "Add aliases to ~/.zshrc or ~/.bashrc:"
echo ""
echo "alias find_${NAME}=\"$BIN_DIR/find_${NAME}.sh\""
echo "alias scan_${NAME}=\"$BIN_DIR/scanner_${NAME}.sh\""