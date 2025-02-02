#!/usr/bin/env bash

# This script downloads and extracts Slicer and selected extensions to a target
# directory. It depends on rsync, curl, and jq.
#
# args: [-r revision] [-e extension] [-d dest] [-s]
# Installs extensions into slicer at dest. multiple -e arguments are accepted; each
#   extension will be installed.
# If -s is present, slicer itself is installed at dest.
# If -r is not present, default to the revision of the latest Slicer release

# Usage:
# Install slicer 5.6.2 (revison 32448) to ./stable
#   slicer-download.sh -r 32448 -d stable -s

# Add BoneTextureExtension to that installation
#   slicer-download.sh -r 32448 -d stable -e BoneTextureExtension

# Do both steps at once
#   slicer-download.sh -r 32448 -d stable -s -e BoneTextureExtension

set -e
set -o pipefail

err() { echo -e >&2 ERROR: $@\\n; }
die() { err $@; exit 1; }

if [[ ! $OSTYPE =~ ^linux ]]; then
    die 'slicer-download.sh currently only supports linux installations.'
fi

declare -a EXTENSIONS

while getopts ":r:e:d:s" opt; do
  case "$opt" in
    r)
      REVISION="${OPTARG}"
      ;;
    e)
      EXTENSIONS+=("${OPTARG}")
      ;;
    d)
      TARGET="${OPTARG}"
      ;;
    s)
      INSTALL_SLICER='yes'
      ;;
    *)
      >&2 echo "Unrecognized argument ${OPTARG}"
      ;;
  esac
done

BASE_URL="https://slicer-packages.kitware.com/api/v1"
APP_ID=$(curl -s "$BASE_URL/app?name=Slicer&limit=1" | jq -r '.[0]._id')

# this would only work on linux since package must be .tar.gz
PACK_OS="linux"
PACK_ARCH="amd64"

function release() {
  # fetch the revision of the most-recent release
  curl -s "$BASE_URL/app/$APP_ID/release?sort=meta.revision&sortdir=-1" | jq -r '.[0].meta.revision'
}

function package() {
  # args: revision
  curl -s "$BASE_URL/app/$APP_ID/package?revision=$1&os=$PACK_OS&arch=$PACK_ARCH&limit=1" | jq '.[0]'
}

function extension() {
  # args: baseName app_revision
  curl -s "$BASE_URL/app/$APP_ID/extension?baseName=$1&app_revision=$2&os=$PACK_OS&arch=$PACK_ARCH&limit=1" | jq '.[0]'
}

function download() {
  # args: id
  curl -# "$BASE_URL/item/$1/download"
}

function flatten() {
  # args: src dest
  # joins all directories in src into one directory called dest.

  rsync -a "$1"/*/* "$2"
}

REVISION="${REVISION:-"$(release)"}"

PACK=$(package "$REVISION")

PACK_ID=$(jq -r '._id' <<< "$PACK")
PACK_REV=$(jq -r '.meta.revision' <<< "$PACK")
PACK_VERSION=$(jq -r '.meta.version' <<< "$PACK")
PACK_NAME=$(jq -r '.name' <<< "$PACK")

TARGET="${TARGET:-"Slicer-$PACK_VERSION"}"

if [[ "$REVISION" != "$PACK_REV" ]]; then
  die "Request revision $REVISION is not available"
fi

>&2 echo "Installing to $TARGET (revision $REVISION): ${INSTALL_SLICER:+"Slicer "}${EXTENSIONS[*]}"

TEMP=$(mktemp -d)

if [[ -n $INSTALL_SLICER ]]; then
  >&2 echo "Downloading Slicer: $PACK_NAME"
  download "$PACK_ID" | tar xz -C "$TEMP"
fi

for EXTENSION in "${EXTENSIONS[@]}"; do
  EXT=$(extension "$EXTENSION" "$PACK_REV")

  EXT_NAME=$(jq -r '.name' <<< "$EXT")
  EXT_ID=$(jq -r '._id' <<< "$EXT")

  >&2 echo "Downloading $EXTENSION: $EXT_NAME"
  download "$EXT_ID" | tar xz -C "$TEMP"
done


>&2 echo "Installing to $TARGET"
flatten "$TEMP" "$TARGET"

echo "$TARGET"
