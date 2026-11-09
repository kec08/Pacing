#!/bin/sh
set -eu

framework="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/onnxruntime.framework"
plist="${framework}/Info.plist"
test -f "$plist" || { echo "error: ONNX Runtime framework Info.plist is missing: $plist" >&2; exit 1; }

/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion ${IPHONEOS_DEPLOYMENT_TARGET}" "$plist"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = YES ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none "$framework"
fi
