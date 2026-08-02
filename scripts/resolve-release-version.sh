#!/usr/bin/env bash
# VERSION ファイルを正本に、bump 種別または明示バージョンから次版を決める。
# 使い方: bash scripts/resolve-release-version.sh <patch|minor|major|custom> [version]
#   version は bump=custom のとき必須。先頭の v はあってもなくてもよい。
# GITHUB_OUTPUT があれば version=X.Y.Z と tag=vX.Y.Z を追記し、無ければ標準出力へ出す。
# GITHUB_STEP_SUMMARY があれば現在／次バージョンを Markdown で追記する。
set -euo pipefail

BUMP="${1:?usage: resolve-release-version.sh <patch|minor|major|custom> [version]}"
RAW_VERSION="${2:-}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_FILE="$ROOT/VERSION"

is_semver() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

normalize_bare() {
  local v="${1#v}"
  if ! is_semver "$v"; then
    echo "version must look like 0.0.4 or v0.0.4, got: $1" >&2
    exit 1
  fi
  echo "$v"
}

read_current() {
  if [ ! -f "$VERSION_FILE" ]; then
    echo "VERSION file not found at $VERSION_FILE" >&2
    exit 1
  fi
  local v
  v="$(tr -d '[:space:]' <"$VERSION_FILE")"
  normalize_bare "$v"
}

CURRENT="$(read_current)"
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
      echo "custom version equals current VERSION ($CURRENT)" >&2
      exit 1
    fi
    ;;
  *)
    echo "bump must be patch, minor, major, or custom; got: $BUMP" >&2
    exit 1
    ;;
esac

TAG="v$NEXT"

if git -C "$ROOT" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "tag already exists: $TAG" >&2
  exit 1
fi

summary() {
  echo "## Version bump"
  echo ""
  echo "- Current: \`$CURRENT\` (from \`VERSION\`)"
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
    echo "version=$NEXT"
    echo "tag=$TAG"
    echo "current=$CURRENT"
  } >>"$GITHUB_OUTPUT"
else
  echo "version=$NEXT"
  echo "tag=$TAG"
  echo "current=$CURRENT"
fi
