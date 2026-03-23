#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./release.sh <version>"
  echo "Example: ./release.sh 1.4.0"
  exit 1
fi

TAG="v$1"

git add -A
git commit -m "$TAG"
git tag "$TAG"
git push origin main --tags

echo "Released $TAG"
