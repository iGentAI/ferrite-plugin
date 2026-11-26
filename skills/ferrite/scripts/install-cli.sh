#!/bin/sh
set -eu

usage() {
  printf '%s\n' 'usage: install-cli.sh [--bin-dir DIR] [--force]'
}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PLUGIN_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)
VERSION=$(sed -n '1p' "$PLUGIN_ROOT/VERSION")
BIN_DIR=${FERRITE_CLI_BIN_DIR:-${XDG_BIN_HOME:-$HOME/.local/bin}}
FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      BIN_DIR=$2
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 64
      ;;
  esac
done

case "$(uname -s):$(uname -m)" in
  Darwin:arm64) TARGET=darwin-arm64 ;;
  Linux:x86_64) TARGET=linux-x86_64 ;;
  Linux:aarch64|Linux:arm64) TARGET=linux-arm64 ;;
  *)
    printf 'ferrite installer: unsupported platform %s/%s\n' "$(uname -s)" "$(uname -m)" >&2
    exit 65
    ;;
esac

ARCHIVE_NAME="ferrite-cli-$VERSION-$TARGET.tar.gz"
# This plugin carries no binary. The archive is fetched from Ferrite's download
# host and must match the checksum pinned in this plugin's SHA256SUMS, which
# was written when the plugin version was cut.
DOWNLOAD_URL="https://downloads.ferrite.cloud/releases/$VERSION/$ARCHIVE_NAME"
CHECKSUMS="$SCRIPT_DIR/SHA256SUMS"
if [ ! -f "$CHECKSUMS" ]; then
  printf '%s\n' 'ferrite installer: checksum manifest is missing' >&2
  exit 67
fi
command -v curl >/dev/null 2>&1 || { printf '%s\n' 'ferrite installer: curl is required' >&2; exit 69; }
EXPECTED=$(awk -v name="$ARCHIVE_NAME" '$2 == name { print $1 }' "$CHECKSUMS")
if [ -z "$EXPECTED" ]; then
  printf 'ferrite installer: no pinned checksum for %s\n' "$ARCHIVE_NAME" >&2
  exit 67
fi
FETCH_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ferrite-cli-fetch.XXXXXX")
trap 'find "$FETCH_DIR" -depth -delete 2>/dev/null || true' EXIT HUP INT TERM
ARCHIVE="$FETCH_DIR/$ARCHIVE_NAME"
if ! curl -fsSL --proto '=https' --tlsv1.2 --max-filesize 67108864 -o "$ARCHIVE" "$DOWNLOAD_URL"; then
  printf 'ferrite installer: could not download %s\n' "$DOWNLOAD_URL" >&2
  exit 66
fi
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL=$(sha256sum "$ARCHIVE" | awk '{ print $1 }')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{ print $1 }')
else
  printf '%s\n' 'ferrite installer: shasum or sha256sum is required' >&2
  exit 69
fi
if [ "$ACTUAL" != "$EXPECTED" ]; then
  printf 'ferrite installer: checksum mismatch for %s\n' "$ARCHIVE_NAME" >&2
  exit 68
fi

DEST="$BIN_DIR/ferrite"
RECEIPT="$BIN_DIR/.ferrite-plugin-receipt"
if [ -x "$DEST" ] && [ "$FORCE" -eq 0 ]; then
  INSTALLED=$($DEST --version 2>/dev/null | awk 'NR == 1 { print $2 }')
  if [ "$INSTALLED" = "$VERSION" ]; then
    if ! "$DEST" add --help >/dev/null 2>&1; then
      printf 'ferrite installer: %s has version %s but lacks the required command surface; rerun with --force to replace it\n' \
        "$DEST" "$INSTALLED" >&2
      exit 73
    fi
    printf 'Ferrite CLI %s is already installed at %s\n' "$VERSION" "$DEST"
    exit 0
  fi
  printf 'ferrite installer: %s contains version %s; rerun with --force to replace it\n' \
    "$DEST" "${INSTALLED:-unknown}" >&2
  exit 73
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ferrite-cli-install.XXXXXX")
trap 'find "$TMP_DIR" "$FETCH_DIR" -depth -delete 2>/dev/null || true' EXIT HUP INT TERM
if tar -tzf "$ARCHIVE" | awk '/(^\/|(^|\/)\.\.($|\/))/ { bad=1 } END { exit bad ? 0 : 1 }'; then
  printf '%s\n' 'ferrite installer: archive contains an unsafe path' >&2
  exit 70
fi
tar -xzf "$ARCHIVE" -C "$TMP_DIR"
if [ ! -f "$TMP_DIR/ferrite" ] || [ -L "$TMP_DIR/ferrite" ]; then
  printf '%s\n' 'ferrite installer: archive does not contain a regular ferrite binary' >&2
  exit 70
fi
ACTUAL_VERSION=$($TMP_DIR/ferrite --version 2>/dev/null | awk 'NR == 1 { print $2 }')
if [ "$ACTUAL_VERSION" != "$VERSION" ]; then
  printf 'ferrite installer: artifact version %s does not match pinned version %s\n' \
    "${ACTUAL_VERSION:-unknown}" "$VERSION" >&2
  exit 71
fi
if ! "$TMP_DIR/ferrite" add --help >/dev/null 2>&1; then
  printf 'ferrite installer: artifact %s lacks the required command surface\n' "$ARCHIVE_NAME" >&2
  exit 71
fi

mkdir -p "$BIN_DIR"
install -m 0755 "$TMP_DIR/ferrite" "$DEST.tmp.$$"
mv -f "$DEST.tmp.$$" "$DEST"
# The archive carries the licence the binary is distributed under; keep it
# beside the receipt so the terms travel with the installation.
LICENSE_DEST="$BIN_DIR/.ferrite-LICENSE"
if [ -f "$TMP_DIR/LICENSE" ] && [ ! -L "$TMP_DIR/LICENSE" ]; then
  install -m 0644 "$TMP_DIR/LICENSE" "$LICENSE_DEST.tmp.$$"
  mv -f "$LICENSE_DEST.tmp.$$" "$LICENSE_DEST"
else
  LICENSE_DEST=
  rm -f "$BIN_DIR/.ferrite-LICENSE"
fi
printf 'version=%s\nsha256=%s\npath=%s\nlicense=%s\n' "$VERSION" "$EXPECTED" "$DEST" "$LICENSE_DEST" > "$RECEIPT.tmp.$$"
chmod 0600 "$RECEIPT.tmp.$$"
mv -f "$RECEIPT.tmp.$$" "$RECEIPT"
printf 'Installed Ferrite CLI %s at %s\n' "$VERSION" "$DEST"
