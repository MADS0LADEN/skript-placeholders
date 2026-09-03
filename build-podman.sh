#!/usr/bin/env bash
#
# build-podman.sh – byg jar via Podman og push til remote.
#
#  1. Bygger et builder-image (JDK 21 + git).
#  2. Kører './gradlew nightlyBuild' i en container.
#  3. git push af nuværende branch til origin.
#  4. Uploader jar'en til en GitHub Release (tag fra gradle.properties, fx v1.8.0).
#
# Brug: ./build-podman.sh [--skip-push] [--skip-release]
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="skript-placeholder-builder:latest"
GRADLE_HOME_VOLUME="skript-placeholder-gradle-home"
VERSION="$(grep '^version=' "$REPO_ROOT/gradle.properties" | cut -d= -f2)"
JAR="build/libs/skript-placeholders-$VERSION.jar"

SKIP_PUSH=false
SKIP_RELEASE=false
for arg in "$@"; do
	case "$arg" in
		--skip-push) SKIP_PUSH=true ;;
		--skip-release) SKIP_RELEASE=true ;;
		*) echo "Ukendt flag: $arg (brug --skip-push og/eller --skip-release)" >&2; exit 1 ;;
	esac
done

cd "$REPO_ROOT"

command -v podman >/dev/null || { echo "FEJL: podman er ikke installeret." >&2; exit 1; }

echo "==> Bygger builder-image ($IMAGE) ..."
podman build -f Containerfile.build -t "$IMAGE" .

echo "==> Bygger jar i container ..."
podman run --rm \
	-v "$REPO_ROOT:/project:z" \
	-v "$GRADLE_HOME_VOLUME:/root/.gradle" \
	-w /project \
	"$IMAGE" ./gradlew nightlyBuild

echo "==> Bygget jar:"
ls -la "$JAR"

if [ "$SKIP_PUSH" = false ]; then
	BRANCH="$(git branch --show-current)"
	echo "==> git push origin $BRANCH ..."
	git push origin "$BRANCH"
else
	echo "==> Springer git push over (--skip-push)."
fi

if [ "$SKIP_RELEASE" = false ]; then
	command -v gh >/dev/null || { echo "FEJL: gh er ikke installeret." >&2; exit 1; }
	TAG="v$VERSION"
	if ! gh release view "$TAG" >/dev/null 2>&1; then
		echo "==> Opretter GitHub release $TAG ..."
		gh release create "$TAG" --title "$TAG" --notes "Automated build."
	fi
	echo "==> Uploader $JAR til release $TAG ..."
	gh release upload "$TAG" "$JAR" --clobber
else
	echo "==> Springer GitHub Release over (--skip-release)."
fi

echo "==> Færdig."
