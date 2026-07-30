#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$PROJECT_ROOT/scripts/lib/profile-engine.sh"

fail() {
    echo "FAIL: $1"
    exit 1
}

BUILD_DESKTOP="kde"
load_desktop_metadata

[[ "$DESKTOP_STATUS" == "stable" ]] || fail "expected DESKTOP_STATUS=stable, got '$DESKTOP_STATUS'"
[[ "$DESKTOP_DISPLAY_MANAGER_PACKAGE" == "sddm" ]] || fail "expected sddm, got '$DESKTOP_DISPLAY_MANAGER_PACKAGE'"
[[ "$DESKTOP_DISPLAY_MANAGER_SERVICE" == "sddm" ]] || fail "expected sddm, got '$DESKTOP_DISPLAY_MANAGER_SERVICE'"
[[ "$DESKTOP_SESSION" == "plasma" ]] || fail "expected plasma, got '$DESKTOP_SESSION'"
[[ "$DESKTOP_BRANDING_PACKAGE" == "gnegnolios-branding-kde" ]] || fail "expected gnegnolios-branding-kde, got '$DESKTOP_BRANDING_PACKAGE'"
[[ "$DESKTOP_DEFAULT_TERMINAL" == "konsole" ]] || fail "expected konsole, got '$DESKTOP_DEFAULT_TERMINAL'"
[[ "$DESKTOP_DEFAULT_FILE_MANAGER" == "dolphin" ]] || fail "expected dolphin, got '$DESKTOP_DEFAULT_FILE_MANAGER'"
[[ "$DESKTOP_DEFAULT_EDITOR" == "kate" ]] || fail "expected kate, got '$DESKTOP_DEFAULT_EDITOR'"
[[ "$DESKTOP_DEFAULT_SCREENSHOT" == "spectacle" ]] || fail "expected spectacle, got '$DESKTOP_DEFAULT_SCREENSHOT'"

echo "PASS: load_desktop_metadata (stable profile)"

BUILD_DESKTOP="_missing_profile_for_test"
if ( load_desktop_metadata ) &>/tmp/test-profile-engine-err; then
    fail "expected load_desktop_metadata to exit non-zero for a missing profile"
fi
grep -q "Missing profile" /tmp/test-profile-engine-err || fail "expected 'Missing profile' error message"

echo "PASS: load_desktop_metadata (missing profile errors out)"
