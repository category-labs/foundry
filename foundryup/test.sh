#!/usr/bin/env bash

# Tests for the bash foundryup shim. Network and installer side effects are
# mocked so this can run in CI without downloading release assets.

# Mocks/globals are used indirectly by the sourced foundryup functions.
# shellcheck disable=SC2034,SC2317

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export FOUNDRYUP_TEST=1
# shellcheck source=/dev/null
. "$SCRIPT_DIR/foundryup"

failures=0
install_tmp=""
fake_archive=""
last_archive_url=""
used_version=""
mock_latest_tag=""

check_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    printf 'ok   - %s\n' "$desc"
  else
    printf 'FAIL - %s\n      expected: %q\n      actual:   %q\n' "$desc" "$expected" "$actual"
    failures=$((failures + 1))
  fi
}

check_success() {
  local desc="$1"
  shift
  if "$@"; then
    printf 'ok   - %s\n' "$desc"
  else
    printf 'FAIL - %s\n' "$desc"
    failures=$((failures + 1))
  fi
}

check_failure() {
  local desc="$1"
  shift
  if "$@"; then
    printf 'FAIL - %s\n' "$desc"
    failures=$((failures + 1))
  else
    printf 'ok   - %s\n' "$desc"
  fi
}

say() { :; }
warn() { :; }

# --- foundryup versioning --------------------------------------------------

check_eq "foundryup uses composite Monad version" \
  "1.5.0-monad-v1.0.0" "$FOUNDRYUP_INSTALLER_VERSION"
check_eq "extract_installer_version parses composite version" \
  "1.5.0-monad-v1.2.3" \
  "$(printf '%s\n' 'FOUNDRYUP_INSTALLER_VERSION="1.5.0-monad-v1.2.3"' | extract_installer_version)"
check_success "version_gt detects newer Monad patch" \
  version_gt 1.5.0-monad-v1.0.1 1.5.0-monad-v1.0.0
check_success "version_gt detects newer Monad minor" \
  version_gt 1.5.0-monad-v1.1.0 1.5.0-monad-v1.0.9
check_success "version_gt detects newer upstream base" \
  version_gt 1.6.0-monad-v1.0.0 1.5.9-monad-v9.9.9
check_failure "version_gt rejects equal versions" \
  version_gt 1.5.0-monad-v1.0.0 1.5.0-monad-v1.0.0
check_failure "version_gt rejects older Monad versions" \
  version_gt 1.5.0-monad-v0.9.9 1.5.0-monad-v1.0.0
check_failure "version_gt rejects malformed versions" version_gt 1.6.0 1.5.0-monad-v1.0.0

check_success "versioned Monad release tag is accepted" \
  is_monad_release_tag v1.7.1-monad-v1.0.0
check_failure "legacy Monad release tag is not a new versioned release" \
  is_monad_release_tag v1.5.0-monad.0.3.0

# --- detect_platform_arch -------------------------------------------------

uname() {
  case "$1" in
    -s) printf 'Linux\n' ;;
    -m) printf 'x86_64\n' ;;
    *) return 1 ;;
  esac
}
sysctl() { return 1; }
unset FOUNDRYUP_PLATFORM FOUNDRYUP_ARCH
detect_platform_arch
check_eq "linux x86_64 maps to linux/amd64 tarball" "linux" "$PLATFORM"
check_eq "x86_64 maps to amd64" "amd64" "$ARCHITECTURE"
check_eq "linux archive extension is tar.gz" "tar.gz" "$EXT"

FOUNDRYUP_PLATFORM=win32
FOUNDRYUP_ARCH=aarch64
detect_platform_arch
check_eq "win32 platform maps to zip" "win32" "$PLATFORM"
check_eq "aarch64 maps to arm64" "arm64" "$ARCHITECTURE"
check_eq "windows archive extension is zip" "zip" "$EXT"
unset -f uname sysctl
unset FOUNDRYUP_PLATFORM FOUNDRYUP_ARCH

# --- Monad release asset selection ----------------------------------------

setup_install_fixture() {
  install_tmp="$(mktemp -d)"
  fake_archive="$install_tmp/foundry.tar.gz"
  mkdir -p "$install_tmp/archive" "$install_tmp/bin" "$install_tmp/versions" "$install_tmp/man"
  for bin in forge cast anvil chisel; do
    printf '#!/usr/bin/env sh\nprintf "%s 0.0.0\\n"\n' "$bin" > "$install_tmp/archive/$bin"
    chmod +x "$install_tmp/archive/$bin"
  done
  tar -czf "$fake_archive" -C "$install_tmp/archive" forge cast anvil chisel

  FOUNDRY_DIR="$install_tmp"
  FOUNDRY_VERSIONS_DIR="$install_tmp/versions"
  FOUNDRY_BIN_DIR="$install_tmp/bin"
  FOUNDRY_MAN_DIR="$install_tmp/man"
  FOUNDRYUP_NETWORK=""
  FOUNDRYUP_REPO=""
  FOUNDRYUP_VERSION=""
  FOUNDRYUP_TAG=""
  FOUNDRYUP_BRANCH=""
  FOUNDRYUP_COMMIT=""
  FOUNDRYUP_PR=""
  FOUNDRYUP_LOCAL_REPO=""
  FOUNDRYUP_IGNORE_VERIFICATION=false
  HASH_NAMES=()
  HASH_VALUES=()
  BINS=(forge cast anvil chisel)
  last_archive_url=""
  used_version=""
  mock_latest_tag=""
}

teardown_install_fixture() {
  rm -rf "$install_tmp"
}

need_cmd() { :; }
banner() { :; }
check_installer_up_to_date() { :; }
check_bins_in_use() { :; }
resolve_latest_release_tag() { printf '%s\n' "$mock_latest_tag"; }
use() { used_version="$FOUNDRYUP_VERSION"; }
uname() {
  case "$1" in
    -s) printf 'Linux\n' ;;
    -m) printf 'x86_64\n' ;;
    *) return 1 ;;
  esac
}
sysctl() { return 1; }

download() {
  if [ -n "${2:-}" ]; then
    last_archive_url="$1"
    cp "$fake_archive" "$2"
  else
    printf 'not a gzip archive'
  fi
}

setup_install_fixture
mock_latest_tag="v1.7.1-monad-v1.0.0"
main --network monad --force --platform linux --arch amd64 >/dev/null 2>&1
check_eq "stable Monad channel uses category-labs/foundry" "category-labs/foundry" "$FOUNDRYUP_REPO"
check_eq "stable Monad channel resolves latest version" "v1.7.1-monad-v1.0.0" "$FOUNDRYUP_TAG"
check_eq "stable Monad channel uses versioned archive" \
  "https://github.com/category-labs/foundry/releases/download/v1.7.1-monad-v1.0.0/foundry_v1.7.1-monad-v1.0.0_linux_amd64.tar.gz" \
  "$last_archive_url"
check_eq "stable Monad channel activates immutable version directory" \
  "v1.7.1-monad-v1.0.0" "$used_version"
teardown_install_fixture

setup_install_fixture
mock_latest_tag="v1.5.0-monad.0.3.0"
main --network monad --force --platform linux --arch amd64 >/dev/null 2>&1
check_eq "stable Monad channel falls back to stable-monad" "stable-monad" "$FOUNDRYUP_TAG"
check_eq "legacy fallback archive name" \
  "https://github.com/category-labs/foundry/releases/download/stable-monad/foundry_stable-monad_linux_amd64.tar.gz" \
  "$last_archive_url"
check_eq "legacy fallback activates stable-monad directory" "stable-monad" "$used_version"
teardown_install_fixture

setup_install_fixture
main --network monad --install stable-monad --force --platform linux --arch amd64 >/dev/null 2>&1
check_eq "explicit stable-monad install remains supported" "stable-monad" "$FOUNDRYUP_TAG"
teardown_install_fixture

setup_install_fixture
main --network monad --install 1.7.1-monad-v0.1.0 --force --platform linux --arch amd64 >/dev/null 2>&1
check_eq "bare Monad release version gets v prefix" "v1.7.1-monad-v0.1.0" "$FOUNDRYUP_VERSION"
check_eq "bare Monad release tag gets v prefix" "v1.7.1-monad-v0.1.0" "$FOUNDRYUP_TAG"
check_eq "bare Monad release archive name" \
  "https://github.com/category-labs/foundry/releases/download/v1.7.1-monad-v0.1.0/foundry_v1.7.1-monad-v0.1.0_linux_amd64.tar.gz" \
  "$last_archive_url"
teardown_install_fixture

unset -f need_cmd banner check_installer_up_to_date check_bins_in_use resolve_latest_release_tag use uname sysctl download

if [ "$failures" -ne 0 ]; then
  printf '\n%d test(s) failed\n' "$failures"
  exit 1
fi

printf '\nall tests passed\n'
