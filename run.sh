#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-gitbrute:latest}"
DOCKER="${DOCKER:-docker}"

if ! command -v "$DOCKER" >/dev/null 2>&1; then
  echo "docker not found" >&2; exit 2
fi

TTY=""
[ -t 1 ] && [ -t 0 ] && TTY="-it"

# mount host git config if present
HOST_GITCONFIG="${HOST_GITCONFIG:-$HOME/.gitconfig}"
GITCONFIG_VOL=""
if [ -f "$HOST_GITCONFIG" ]; then
  # mount into root path by default; if running as host user we'll mount into $HOME below
  GITCONFIG_VOL="-v $HOST_GITCONFIG:/root/.gitconfig:ro"
fi

# run container as host user and mount host $HOME when requested
DOCKER_USER_ARGS=""
# default to running as host user to avoid ownership issues
: ${RUN_AS_USER:=1}
if [ "${RUN_AS_USER}" != "0" ]; then
  DOCKER_USER_ARGS+="-u $(id -u):$(id -g)"
  # mount host home and make it available inside container
  DOCKER_USER_ARGS+=" -v $HOME:$HOME:rw -e HOME=$HOME"
  # when running as host user, ensure gitconfig mounts into the user's home
  if [ -f "$HOST_GITCONFIG" ]; then
    GITCONFIG_VOL="-v $HOST_GITCONFIG:$HOME/.gitconfig:ro"
  fi
fi

# SSH agent forwarding
SSH_ARGS=""
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ -S "$SSH_AUTH_SOCK" ]; then
  SSH_ARGS="-v $SSH_AUTH_SOCK:$SSH_AUTH_SOCK -e SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
fi

# GPG forwarding: prefer GNUPGHOME or fallback to ~/.gnupg
GPG_ARGS=""
if [ -n "${GNUPGHOME:-}" ] && [ -d "$GNUPGHOME" ]; then
  GPG_ARGS="-v $GNUPGHOME:$GNUPGHOME:rw -e GNUPGHOME=$GNUPGHOME"
elif [ -d "$HOME/.gnupg" ]; then
  GPG_ARGS="-v $HOME/.gnupg:$HOME/.gnupg:rw -e GNUPGHOME=$HOME/.gnupg"
fi

# build image if missing
if ! "$DOCKER" image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
  echo "Image ${IMAGE_NAME} not found locally — building..."
  if ! ./build.sh; then
    echo "Failed to build image" >&2; exit 1
  fi
fi

exec "$DOCKER" run --rm $TTY $DOCKER_USER_ARGS $GITCONFIG_VOL $SSH_ARGS $GPG_ARGS -v "$(pwd)":/workdir -w /workdir \
  --entrypoint /bin/sh "${IMAGE_NAME}" -c \
  'git config --global --add safe.directory /workdir >/dev/null 2>&1 || true; exec /usr/local/bin/gitbrute "$@"' -- "$@"
