#!/usr/bin/env bash
set -euo pipefail

PLIST_PATH="${1:-ios/Runner/GoogleService-Info.plist}"
INFO_PLIST="${2:-ios/Runner/Info.plist}"

if [[ ! -f "$PLIST_PATH" ]]; then
  echo "ERROR: Missing $PLIST_PATH. Download GoogleService-Info.plist for com.dortapp.dort from Firebase project dorduncu-8e599." >&2
  exit 1
fi

if grep -q "REPLACE_FROM_FIREBASE_CONSOLE" "$PLIST_PATH"; then
  echo "ERROR: $PLIST_PATH still contains placeholder values." >&2
  exit 1
fi

read_plist_key() {
  local file="$1"
  local key="$2"
  if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Print :$key" "$file" 2>/dev/null || true
  else
    python3 - "$file" "$key" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    data = plistlib.load(f)
print(data.get(sys.argv[2], ""))
PY
  fi
}

BUNDLE_ID="$(read_plist_key "$PLIST_PATH" "BUNDLE_ID")"
PROJECT_ID="$(read_plist_key "$PLIST_PATH" "PROJECT_ID")"
GOOGLE_APP_ID="$(read_plist_key "$PLIST_PATH" "GOOGLE_APP_ID")"
REVERSED_CLIENT_ID="$(read_plist_key "$PLIST_PATH" "REVERSED_CLIENT_ID")"

if [[ "$BUNDLE_ID" != "com.dortapp.dort" ]]; then
  echo "ERROR: GoogleService-Info.plist BUNDLE_ID is '$BUNDLE_ID', expected 'com.dortapp.dort'." >&2
  exit 1
fi

if [[ "$PROJECT_ID" != "dorduncu-8e599" ]]; then
  echo "ERROR: GoogleService-Info.plist PROJECT_ID is '$PROJECT_ID', expected 'dorduncu-8e599'." >&2
  exit 1
fi

if [[ -z "$GOOGLE_APP_ID" ]]; then
  echo "ERROR: GoogleService-Info.plist is missing GOOGLE_APP_ID." >&2
  exit 1
fi

# Firebase Phone Auth reCAPTCHA fallback requires the encoded app ID URL scheme
# (app-1-256435983692-ios-...) and REVERSED_CLIENT_ID (when present).
ENCODED_APP_ID="app-${GOOGLE_APP_ID//:/-}"

python3 - "$INFO_PLIST" "$ENCODED_APP_ID" "$REVERSED_CLIENT_ID" <<'PY'
import plistlib, sys

info_path, encoded_app_id, reversed_client_id = sys.argv[1:4]
with open(info_path, "rb") as f:
    info = plistlib.load(f)

schemes_to_ensure = [encoded_app_id]
if reversed_client_id:
    schemes_to_ensure.append(reversed_client_id)

url_types = list(info.get("CFBundleURLTypes") or [])
existing = set()
for entry in url_types:
    for scheme in entry.get("CFBundleURLSchemes") or []:
        existing.add(str(scheme))

changed = False
for scheme in schemes_to_ensure:
    if scheme and scheme not in existing:
        url_types.append({
            "CFBundleTypeRole": "Editor",
            "CFBundleURLSchemes": [scheme],
        })
        existing.add(scheme)
        changed = True

if changed:
    info["CFBundleURLTypes"] = url_types
    with open(info_path, "wb") as f:
        plistlib.dump(info, f, sort_keys=True)
    print(f"Injected Firebase Phone Auth URL schemes into {info_path}: {schemes_to_ensure}")
else:
    print(f"Firebase Phone Auth URL schemes already present in {info_path}.")
PY

echo "Validated Firebase iOS configuration for $BUNDLE_ID ($GOOGLE_APP_ID)."
