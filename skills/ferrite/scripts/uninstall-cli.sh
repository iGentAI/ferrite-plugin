#!/bin/sh
set -eu

BIN_DIR=${FERRITE_CLI_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}
DEST="$BIN_DIR/ferrite"
RECEIPT="$BIN_DIR/.ferrite-plugin-receipt"
if [ ! -f "$RECEIPT" ]; then
  printf 'ferrite uninstaller: no plugin receipt at %s; refusing to remove an unowned binary\n' "$RECEIPT" >&2
  exit 1
fi
RECORDED_PATH=$(awk -F= '$1 == "path" { print substr($0, 6) }' "$RECEIPT")
if [ "$RECORDED_PATH" != "$DEST" ]; then
  printf '%s\n' 'ferrite uninstaller: receipt path mismatch; refusing removal' >&2
  exit 1
fi
if [ -e "$DEST" ]; then
  find "$DEST" -maxdepth 0 -type f -delete
fi
if [ -f "$BIN_DIR/.ferrite-LICENSE" ]; then
  find "$BIN_DIR/.ferrite-LICENSE" -maxdepth 0 -type f -delete
fi
find "$RECEIPT" -maxdepth 0 -type f -delete
printf 'Removed plugin-managed Ferrite CLI from %s\n' "$DEST"
