#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

TARGET="${1:-all}"
SDK="${SDK:-${TMPDIR:-/tmp}/sdk/iPhoneOS3.1.3.sdk}"
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

usage() {
    cat <<'EOF'
usage: ./build.sh [armv6|armv7|all|clean]

  armv6   build for iPod touch / iPhone OS 3.1.3  -> build/
  armv7   build for iPad / iOS 4.3.3              -> build-armv7/
  all     build both (default)
  clean   remove build/ and build-armv7/

environment:
  SDK=/path/to/iPhoneOS3.1.3.sdk   override SDK location
  JOBS=N                           override parallel compile jobs
EOF
}

case "$TARGET" in
    armv6|ipod) MODE=armv6 ;;
    armv7|ipad) MODE=armv7 ;;
    all)        MODE=all ;;
    clean)      rm -rf build build-armv7
                echo "removed build/ build-armv7/"
                exit 0 ;;
    -h|--help|help) usage; exit 0 ;;
    *)          usage; exit 1 ;;
esac

if [ ! -f "$SDK/System/Library/Frameworks/UIKit.framework/Headers/UIKit.h" ]; then
    echo "error: iPhoneOS3.1.3 SDK not found at $SDK" >&2
    echo "set SDK=/path/to/iPhoneOS3.1.3.sdk" >&2
    exit 1
fi

if ! xcrun -f clang >/dev/null 2>&1; then
    echo "error: clang not found (xcrun -f clang)" >&2
    exit 1
fi

if ! command -v ldid >/dev/null 2>&1; then
    echo "error: ldid not found in PATH" >&2
    exit 1
fi

ARMV7_CFLAGS="-target armv7-apple-ios3.1.3 -isysroot $SDK -O2 -marm -fno-objc-arc -fno-stack-protector -Iclient -Ivendor -Ivendor/mbedtls/include -Wno-deprecated-declarations"

build_armv6() {
    echo "== armv6 / iPod (build/) =="
    make -j"$JOBS" SDK="$SDK"
    file build/OldSeek.app/OldSeek
}

build_armv7() {
    echo "== armv7 / iPad (build-armv7/) =="
    make -j"$JOBS" BUILD=build-armv7 SDK="$SDK" CFLAGS="$ARMV7_CFLAGS"
    file build-armv7/OldSeek.app/OldSeek
}

case "$MODE" in
    armv6) build_armv6 ;;
    armv7) build_armv7 ;;
    all)   build_armv6
           build_armv7 ;;
esac
