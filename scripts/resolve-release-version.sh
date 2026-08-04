#!/usr/bin/env bash
# プラットフォーム別バージョンファイルを正本に、次版を決める。
# 使い方:
#   bash scripts/resolve-release-version.sh <platform> <patch|minor|major|custom> [version]
#   version は bump=custom のとき必須。先頭の v はあってもなくてもよい。
#
# 正本の置き場は versions/<platform>（いまは macos のみ。windows などを後から足す）。
# タグ名:
#   macos   → vX.Y.Z          （UpdateChecker の releases/latest 互換）
#   windows → windows-vX.Y.Z  （将来。macOS の latest を押しのけない）
#
# GITHUB_OUTPUT があれば version / tag / current / platform を追記する。
set -euo pipefail

PLATFORM="${1:?usage: resolve-release-version.sh <platform> <patch|minor|major|custom> [version]}"
BUMP="${2:?usage: resolve-release-version.sh <platform> <patch|minor|major|custom> [version]}"
RAW_VERSION="${3:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/versions/$PLATFORM"

# 出荷対象として認められるプラットフォーム。新しい OS を足すときはここに追記する。
known_platform() {
  case "$1" in
    macos) return 0 ;;
    # windows) return 0 ;;
    *) return 1 ;;
  esac
}

tag_for() {
  local platform="$1" bare="$2"
  case "$platform" in
    macos) echo "v${bare}" ;;
    windows) echo "windows-v${bare}" ;;
    *)
      echo "no tag scheme for platform: $platform" >&2
      exit 1
      ;;
  esac
}

is_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

normalize_bare() {
  local v="${1#v}"
  # windows-v1.2.3 のような接頭辞付き入力も落とす。
  v="${v#windows-}"
  v="${v#v}"
  if ! is_semver "$v"; then
    echo "version must look like 0.0.4 or v0.0.4, got: $1" >&2
    exit 1
  fi
  echo "$v"
}

if ! known_platform "$PLATFORM"; then
  echo "unknown or not-yet-enabled platform: $PLATFORM (known: macos)" >&2
  exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
  echo "version file not found: versions/$PLATFORM" >&2
  exit 1
fi

CURRENT="$(normalize_bare "$(tr -d '[:space:]' <"$VERSION_FILE")")"
NEXT=""

case "$BUMP" in
  patch|minor|major)
    IFS=. read -r major minor patch <<<"$CURRENT"
    case "$BUMP" in
      major)
        major=$((major + 1))
        minor=0
        patch=0
        ;;
      minor)
        minor=$((minor + 1))
        patch=0
        ;;
      patch)
        patch=$((patch + 1))
        ;;
    esac
    NEXT="${major}.${minor}.${patch}"
    ;;
  custom)
    if [ -z "$RAW_VERSION" ]; then
      echo "bump=custom requires version (without needing a leading v)" >&2
      exit 1
    fi
    NEXT="$(normalize_bare "$RAW_VERSION")"
    if [ "$NEXT" = "$CURRENT" ]; then
      echo "custom version equals current versions/$PLATFORM ($CURRENT)" >&2
      exit 1
    fi
    ;;
  *)
    echo "bump must be patch, minor, major, or custom; got: $BUMP" >&2
    exit 1
    ;;
esac

TAG="$(tag_for "$PLATFORM" "$NEXT")"

if git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag already exists: $TAG" >&2
  exit 1
fi

summary() {
  echo "## Version bump"
  echo ""
  echo "- Platform: \`$PLATFORM\`"
  echo "- Current: \`$CURRENT\` (from \`versions/$PLATFORM\`)"
  echo "- Bump: \`$BUMP\`"
  if [ "$BUMP" = "custom" ] && [ -n "$RAW_VERSION" ]; then
    echo "- Input: \`$RAW_VERSION\`"
  fi
  echo "- Next: \`$NEXT\` (tag \`$TAG\`)"
}

summary >&2
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  summary >>"$GITHUB_STEP_SUMMARY"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "platform=$PLATFORM"
    echo "version=$NEXT"
    echo "tag=$TAG"
    echo "current=$CURRENT"
    echo "version_file=versions/$PLATFORM"
  } >>"$GITHUB_OUTPUT"
else
  echo "platform=$PLATFORM"
  echo "version=$NEXT"
  echo "tag=$TAG"
  echo "current=$CURRENT"
  echo "version_file=versions/$PLATFORM"
fi
