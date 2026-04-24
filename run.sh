#!/bin/bash
#
# Docker script to configure and start a Whisper speech-to-text server
#
# DO NOT RUN THIS SCRIPT ON YOUR PC OR MAC! THIS IS ONLY MEANT TO BE RUN
# IN A CONTAINER!
#
# This file is part of Whisper Docker image, available at:
# https://github.com/hwdsl2/docker-whisper
#
# Copyright (C) 2026 Lin Song <linsongui@gmail.com>
#
# This work is licensed under the MIT License
# See: https://opensource.org/licenses/MIT

export PATH="/opt/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

exiterr()  { echo "Error: $1" >&2; exit 1; }
nospaces() { printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//'; }
noquotes() { printf '%s' "$1" | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'$/\1/"; }

check_port() {
  printf '%s' "$1" | tr -d '\n' | grep -Eq '^[0-9]+$' \
  && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

check_ip() {
  IP_REGEX='^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$'
  printf '%s' "$1" | tr -d '\n' | grep -Eq "$IP_REGEX"
}

# Source bind-mounted env file if present (takes precedence over --env-file)
if [ -f /whisper.env ]; then
  # shellcheck disable=SC1091
  . /whisper.env
fi

if [ ! -f "/.dockerenv" ] && [ ! -f "/run/.containerenv" ] \
  && [ -z "$KUBERNETES_SERVICE_HOST" ] \
  && ! head -n 1 /proc/1/sched 2>/dev/null | grep -q '^run\.sh '; then
  exiterr "This script ONLY runs in a container (e.g. Docker, Podman)."
fi

# Read and sanitize environment variables
WHISPER_MODEL=$(nospaces "$WHISPER_MODEL")
WHISPER_MODEL=$(noquotes "$WHISPER_MODEL")
WHISPER_LANGUAGE=$(nospaces "$WHISPER_LANGUAGE")
WHISPER_LANGUAGE=$(noquotes "$WHISPER_LANGUAGE")
WHISPER_PORT=$(nospaces "$WHISPER_PORT")
WHISPER_PORT=$(noquotes "$WHISPER_PORT")
WHISPER_DEVICE=$(nospaces "$WHISPER_DEVICE")
WHISPER_DEVICE=$(noquotes "$WHISPER_DEVICE")
WHISPER_COMPUTE_TYPE=$(nospaces "$WHISPER_COMPUTE_TYPE")
WHISPER_COMPUTE_TYPE=$(noquotes "$WHISPER_COMPUTE_TYPE")
WHISPER_THREADS=$(nospaces "$WHISPER_THREADS")
WHISPER_THREADS=$(noquotes "$WHISPER_THREADS")
WHISPER_API_KEY=$(nospaces "$WHISPER_API_KEY")
WHISPER_API_KEY=$(noquotes "$WHISPER_API_KEY")
WHISPER_LOG_LEVEL=$(nospaces "$WHISPER_LOG_LEVEL")
WHISPER_LOG_LEVEL=$(noquotes "$WHISPER_LOG_LEVEL")
WHISPER_BEAM=$(nospaces "$WHISPER_BEAM")
WHISPER_BEAM=$(noquotes "$WHISPER_BEAM")
WHISPER_LOCAL_ONLY=$(nospaces "$WHISPER_LOCAL_ONLY")
WHISPER_LOCAL_ONLY=$(noquotes "$WHISPER_LOCAL_ONLY")

# Save whether the user explicitly set WHISPER_COMPUTE_TYPE (used below
# to auto-select float16 for CUDA when no explicit type was provided).
_USER_COMPUTE_TYPE="$WHISPER_COMPUTE_TYPE"

# Apply defaults
[ -z "$WHISPER_MODEL" ]        && WHISPER_MODEL=base
[ -z "$WHISPER_LANGUAGE" ]     && WHISPER_LANGUAGE=auto
[ -z "$WHISPER_PORT" ]         && WHISPER_PORT=9000
[ -z "$WHISPER_DEVICE" ]       && WHISPER_DEVICE=cpu
[ -z "$WHISPER_COMPUTE_TYPE" ] && WHISPER_COMPUTE_TYPE=int8
[ -z "$WHISPER_THREADS" ]      && WHISPER_THREADS=2
[ -z "$WHISPER_LOG_LEVEL" ]    && WHISPER_LOG_LEVEL=INFO
[ -z "$WHISPER_BEAM" ]         && WHISPER_BEAM=5

# Validate port
if ! check_port "$WHISPER_PORT"; then
  exiterr "WHISPER_PORT must be an integer between 1 and 65535."
fi

# Validate model name
case "$WHISPER_MODEL" in
  tiny|tiny.en|base|base.en|small|small.en|medium|medium.en|\
  large-v1|large-v2|large-v3|large-v3-turbo|turbo) ;;
  *) exiterr "WHISPER_MODEL '$WHISPER_MODEL' is not recognized. Valid options: tiny, tiny.en, base, base.en, small, small.en, medium, medium.en, large-v1, large-v2, large-v3, large-v3-turbo, turbo" ;;
esac

# Validate device
case "$WHISPER_DEVICE" in
  cpu|cuda) ;;
  auto)
    # Auto-detect: use CUDA if an NVIDIA GPU is available, otherwise fall back to CPU
    if [ -e /dev/nvidia0 ] || nvidia-smi >/dev/null 2>&1; then
      WHISPER_DEVICE=cuda
    else
      WHISPER_DEVICE=cpu
    fi
    ;;
  *) exiterr "WHISPER_DEVICE must be one of: cpu, cuda, auto." ;;
esac

# Adjust default compute type for CUDA (float16 is optimal on GPU)
if [ "$WHISPER_DEVICE" = "cuda" ] && [ -z "$_USER_COMPUTE_TYPE" ]; then
  WHISPER_COMPUTE_TYPE=float16
fi

# Validate compute type
case "$WHISPER_COMPUTE_TYPE" in
  int8|int8_float16|int8_float32|int8_bfloat16|int16|float16|float32|bfloat16) ;;
  *) exiterr "WHISPER_COMPUTE_TYPE '$WHISPER_COMPUTE_TYPE' is not valid. Use: int8, float16, float32, etc." ;;
esac

# Validate log level
case "$WHISPER_LOG_LEVEL" in
  DEBUG|INFO|WARNING|ERROR|CRITICAL) ;;
  *) exiterr "WHISPER_LOG_LEVEL must be one of: DEBUG, INFO, WARNING, ERROR, CRITICAL." ;;
esac

# Validate thread count
if ! printf '%s' "$WHISPER_THREADS" | grep -Eq '^[1-9][0-9]*$'; then
  exiterr "WHISPER_THREADS must be a positive integer."
fi

# Validate beam size
if ! printf '%s' "$WHISPER_BEAM" | grep -Eq '^[1-9][0-9]*$'; then
  exiterr "WHISPER_BEAM must be a positive integer (e.g. 1, 5)."
fi

mkdir -p /var/lib/whisper
# Create the dedicated temp directory for audio uploads.
# TMPDIR is set to this path in the Dockerfile so that Python's tempfile module
# will automatically use it, keeping transient audio data off the main filesystem.
mkdir -p /run/whisper-temp

# Determine server address for display
public_ip=$(curl -s --max-time 10 http://ipv4.icanhazip.com 2>/dev/null || true)
check_ip "$public_ip" || public_ip=$(curl -s --max-time 10 http://ip1.dynupdate.no-ip.com 2>/dev/null || true)
if check_ip "$public_ip"; then
  server_addr="$public_ip"
else
  server_addr="<server ip>"
fi

# Export all config for the Python API server
export WHISPER_MODEL
export WHISPER_LANGUAGE
export WHISPER_PORT
export WHISPER_DEVICE
export WHISPER_COMPUTE_TYPE
export WHISPER_THREADS
export WHISPER_API_KEY
export WHISPER_LOG_LEVEL
export WHISPER_BEAM
export WHISPER_LOCAL_ONLY
# Point faster-whisper / HuggingFace Hub at the persistent Docker volume
export HF_HOME=/var/lib/whisper

# Persist config values so whisper_manage can read them without the env file
printf '%s' "$WHISPER_PORT"  > /var/lib/whisper/.port
printf '%s' "$WHISPER_MODEL" > /var/lib/whisper/.model
printf '%s' "$server_addr"   > /var/lib/whisper/.server_addr

echo
echo "Whisper Docker - https://github.com/hwdsl2/docker-whisper"

if ! grep -q " /var/lib/whisper " /proc/mounts 2>/dev/null; then
  echo
  echo "Note: /var/lib/whisper is not mounted. Model files will be lost on"
  echo "      container removal. Mount a Docker volume at /var/lib/whisper"
  echo "      to persist the downloaded model across container restarts."
fi

echo
echo "Starting Whisper speech-to-text server..."
echo "  Model:    $WHISPER_MODEL"
echo "  Device:   $WHISPER_DEVICE ($WHISPER_COMPUTE_TYPE)"
echo "  Language: $WHISPER_LANGUAGE"
echo "  Port:     $WHISPER_PORT"
echo "  Beam:     $WHISPER_BEAM"
if [ -n "$WHISPER_LOCAL_ONLY" ]; then
  echo "  Mode:     local-only (no HuggingFace downloads)"
fi

if [ -z "$WHISPER_LOCAL_ONLY" ]; then
  # Determine the expected HuggingFace cache directory for the active model.
  # large-v3-turbo and its alias 'turbo' are hosted under mobiuslabsgmbh on HF,
  # not under Systran, so their cache directory name differs from other models.
  _model_in_cache() {
    local m="$1"
    [ -d "/var/lib/whisper/models--Systran--faster-whisper-${m}" ] && return 0
    [ -d "/var/lib/whisper/models--openai--whisper-${m}" ] && return 0
    case "$m" in
      large-v3-turbo|turbo)
        [ -d "/var/lib/whisper/models--mobiuslabsgmbh--faster-whisper-large-v3-turbo" ] && return 0
        ;;
    esac
    return 1
  }
  if ! _model_in_cache "$WHISPER_MODEL"; then
    echo
    echo "Note: Model '$WHISPER_MODEL' not found in cache. It will be downloaded"
    echo "      from HuggingFace on first start. This may take several minutes."
  fi
fi
echo

# Graceful shutdown — registered before starting the server so any SIGTERM
# received during the model-download startup phase is handled cleanly.
cleanup() {
  echo
  echo "Stopping Whisper server..."
  kill "${WHISPER_PID:-}" 2>/dev/null
  wait "${WHISPER_PID:-}" 2>/dev/null
  exit 0
}
trap cleanup INT TERM

# Start the FastAPI server in the background
cd /opt/src && python3 /opt/src/api_server.py &
WHISPER_PID=$!

# Wait for the server to become ready.
# Allow up to 300 seconds — first-run model download can take several minutes
# on a slow connection even for the base model (~145 MB).
wait_for_server() {
  local i=0
  while [ "$i" -lt 300 ]; do
    if ! kill -0 "$WHISPER_PID" 2>/dev/null; then
      return 1
    fi
    if curl -sf "http://127.0.0.1:${WHISPER_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  return 1
}

if ! wait_for_server; then
  if ! kill -0 "$WHISPER_PID" 2>/dev/null; then
    echo "Error: Whisper server failed to start. Check the container logs for details." >&2
  else
    echo "Error: Whisper server did not become ready within 300 seconds." >&2
    kill "$WHISPER_PID" 2>/dev/null
  fi
  exit 1
fi

echo
echo "==========================================================="
echo " Whisper speech-to-text server is ready"
echo "==========================================================="
echo " Model:    $WHISPER_MODEL"
echo " Endpoint: http://${server_addr}:${WHISPER_PORT}"
echo "==========================================================="
echo
echo "Transcribe an audio file:"
echo "  curl http://${server_addr}:${WHISPER_PORT}/v1/audio/transcriptions \\"
echo "    -F file=@audio.mp3 -F model=whisper-1"
echo
if [ -n "$WHISPER_API_KEY" ]; then
  echo "API key authentication is enabled."
  echo "Include header:  -H \"Authorization: Bearer \$WHISPER_API_KEY\""
  echo
fi
echo "Interactive API docs: http://${server_addr}:${WHISPER_PORT}/docs"
echo
echo "To set up HTTPS, see: Using a reverse proxy"
echo "  https://github.com/hwdsl2/docker-whisper#using-a-reverse-proxy"
echo
echo "Setup complete."
echo

# Wait for the server process to exit
wait "$WHISPER_PID"