#!/bin/sh
set -eu

EXPECTED_VERSION=$(sed -n '1p' "$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)/VERSION")
if ! command -v ferrite >/dev/null 2>&1; then
  printf '%s\n' '{"status":"missing","compatible":false}'
  exit 1
fi

CLI_PATH=$(command -v ferrite)
ACTUAL_VERSION=$($CLI_PATH --version 2>/dev/null | awk 'NR == 1 { print $2 }')
if [ "$ACTUAL_VERSION" != "$EXPECTED_VERSION" ]; then
  printf '{"status":"version_mismatch","compatible":false,"expected":"%s","actual":"%s","path":"%s"}\n' \
    "$EXPECTED_VERSION" "$ACTUAL_VERSION" "$CLI_PATH"
  exit 2
fi
if ! "$CLI_PATH" add --help >/dev/null 2>&1; then
  printf '{"status":"capability_mismatch","compatible":false,"expected":"%s","actual":"%s","path":"%s","missing":"add"}\n' \
    "$EXPECTED_VERSION" "$ACTUAL_VERSION" "$CLI_PATH"
  exit 2
fi
printf '{"status":"ready","compatible":true,"expected":"%s","actual":"%s","path":"%s"}\n' \
  "$EXPECTED_VERSION" "$ACTUAL_VERSION" "$CLI_PATH"
