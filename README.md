[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Docker image for Whisper Speech-to-Text

[![Build Status](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

A Docker image to run a [Whisper](https://github.com/openai/whisper) speech-to-text server, powered by [faster-whisper](https://github.com/SYSTRAN/faster-whisper). Provides an OpenAI-compatible audio transcription API. Based on Debian (python:3.12-slim). Designed to be simple, private, and self-hosted.

- OpenAI-compatible `POST /v1/audio/transcriptions` endpoint — any app using the OpenAI Whisper API switches with a one-line change
- Supports all Whisper models: `tiny`, `base`, `small`, `medium`, `large-v3`, `large-v3-turbo` and more
- Model management via a helper script (`whisper_manage`)
- Audio stays on your server — no data sent to third parties
- All major audio formats supported (mp3, m4a, wav, webm, ogg, flac, and all ffmpeg formats)
- Multiple response formats: JSON, plain text, verbose JSON, SRT subtitles, WebVTT subtitles
- Offline/air-gapped mode — run without internet access using pre-cached models (`WHISPER_LOCAL_ONLY`)
- Automatically built and published via [GitHub Actions](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml)
- Persistent model cache via a Docker volume
- Multi-arch: `linux/amd64`, `linux/arm64`

**Also available:** Docker images for [LiteLLM](https://github.com/hwdsl2/docker-litellm), [WireGuard](https://github.com/hwdsl2/docker-wireguard), [OpenVPN](https://github.com/hwdsl2/docker-openvpn), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server) and [Headscale](https://github.com/hwdsl2/docker-headscale).

## Quick start

Use this command to set up a Whisper server:

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also replace `-p 9000:9000` with `-p 127.0.0.1:9000:9000` in the `docker run` command above, to prevent direct access to the unencrypted port.

The Whisper `base` model (~145 MB) is downloaded and cached on first start. Check the logs to confirm the server is ready:

```bash
docker logs whisper
```

Once you see "Whisper speech-to-text server is ready", transcribe your first audio file:

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

**Response:**
```json
{"text": "Your transcribed text appears here."}
```

## Requirements

- A Linux server (local or cloud) with Docker installed
- Supported architectures: `amd64` (x86_64), `arm64` (e.g. Raspberry Pi 4/5, AWS Graviton)
- Minimum RAM: ~500 MB free for the default `base` model (see [model table](#switching-models))
- Internet access for the initial model download (the model is cached locally afterwards). Not required if using `WHISPER_LOCAL_ONLY=true` with pre-cached models.

For internet-facing deployments, see [Using a reverse proxy](#using-a-reverse-proxy) to add HTTPS.

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/whisper-server/):

```bash
docker pull hwdsl2/whisper-server
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/whisper-server):

```bash
docker pull quay.io/hwdsl2/whisper-server
docker image tag quay.io/hwdsl2/whisper-server hwdsl2/whisper-server
```

Supported platforms: `linux/amd64` and `linux/arm64`.

## Environment variables

All variables are optional. If not set, secure defaults are used automatically.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](whisper.env.example)):

| Variable | Description | Default |
|---|---|---|
| `WHISPER_MODEL` | Whisper model to use. See [model table](#switching-models) for options. | `base` |
| `WHISPER_LANGUAGE` | Default transcription language. BCP-47 code (e.g. `en`, `fr`, `de`, `zh`, `ja`) or `auto` to autodetect. | `auto` |
| `WHISPER_PORT` | HTTP port for the API (1–65535). | `9000` |
| `WHISPER_DEVICE` | Compute device for inference. | `cpu` |
| `WHISPER_COMPUTE_TYPE` | Quantization / compute type. `int8` is recommended. | `int8` |
| `WHISPER_THREADS` | CPU threads for inference. Set to the number of physical cores for best latency. | `2` |
| `WHISPER_API_KEY` | Optional Bearer token. If set, all API requests must include `Authorization: Bearer <key>`. | *(not set)* |
| `WHISPER_LOG_LEVEL` | Log level: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. | `INFO` |
| `WHISPER_BEAM` | Beam size for transcription decoding. Higher values may improve accuracy at the cost of speed. Use `1` for fastest (greedy) decoding. | `5` |
| `WHISPER_LOCAL_ONLY` | When set to any non-empty value (e.g. `true`), disables all HuggingFace model downloads. For offline or air-gapped deployments with pre-cached models. | *(not set)* |

**Note:** In your `env` file, you may enclose values in single quotes, e.g. `VAR='value'`. Do not add spaces around `=`. If you change `WHISPER_PORT`, update the `-p` flag in the `docker run` command accordingly.

Example using an `env` file:

```bash
cp whisper.env.example whisper.env
# Edit whisper.env with your settings, then:
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -v ./whisper.env:/whisper.env:ro \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

The env file is bind-mounted into the container, so changes are picked up on every restart without recreating the container.

Alternatively, pass it with `--env-file`:

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    --env-file=whisper.env \
    -d hwdsl2/whisper-server
```

## Using docker-compose

```bash
cp whisper.env.example whisper.env
# Edit whisper.env as needed, then:
docker compose up -d
docker logs whisper
```

Example `docker-compose.yml` (already included):

```yaml
services:
  whisper:
    image: hwdsl2/whisper-server
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      - ./whisper.env:/whisper.env:ro

volumes:
  whisper-data:
```

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also change `"9000:9000/tcp"` to `"127.0.0.1:9000:9000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

## API reference

The API is fully compatible with [OpenAI's audio transcription endpoint](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create). Any application already calling `https://api.openai.com/v1/audio/transcriptions` can switch to self-hosted by setting:

```
OPENAI_BASE_URL=http://your_server_ip:9000
```

### Transcribe audio

```
POST /v1/audio/transcriptions
Content-Type: multipart/form-data
```

**Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `file` | file | ✅ | Audio file. Supported formats: `mp3`, `mp4`, `m4a`, `wav`, `webm`, `ogg`, `flac` and all other formats supported by ffmpeg. |
| `model` | string | ✅ | Pass `whisper-1` (value is accepted but the active model is always used). |
| `language` | string | — | BCP-47 language code. Overrides `WHISPER_LANGUAGE` for this request. |
| `prompt` | string | — | Optional text to guide the model's style or continue a previous segment. |
| `response_format` | string | — | Output format. Default: `json`. See [response formats](#response-formats). |
| `temperature` | float | — | Sampling temperature (0–1). Default: `0`. |

**Example:**

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -F file=@meeting.m4a \
    -F model=whisper-1 \
    -F language=en
```

With API key authentication:

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer your_api_key" \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

### Response formats

| `response_format` | Description |
|---|---|
| `json` | `{"text": "..."}` — default, matches OpenAI's basic response |
| `text` | Plain text, no JSON wrapper |
| `verbose_json` | Full JSON with language, duration, per-segment timestamps, log-probabilities |
| `srt` | SubRip subtitle format (`.srt`) |
| `vtt` | WebVTT subtitle format (`.vtt`) |

**Example — get SRT subtitles:**

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -F file=@video.mp4 \
    -F model=whisper-1 \
    -F response_format=srt
```

**Example — verbose JSON with timestamps:**

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1 \
    -F response_format=verbose_json
```

### List models

```
GET /v1/models
```

Returns the active model in OpenAI-compatible format.

```bash
curl http://your_server_ip:9000/v1/models
```

### Interactive API docs

An interactive Swagger UI is available at:

```
http://your_server_ip:9000/docs
```

## Persistent data

All server data is stored in the Docker volume (`/var/lib/whisper` inside the container):

```
/var/lib/whisper/
├── hub/                  # Cached Whisper model files (downloaded from HuggingFace)
├── .port                 # Active port (used by whisper_manage)
├── .model                # Active model name (used by whisper_manage)
└── .server_addr          # Cached server IP (used by whisper_manage)
```

Back up the Docker volume to preserve downloaded models. Models are large (145 MB – 3 GB) and can take several minutes to download on first start; preserving the volume avoids re-downloading on container recreation.

## Managing the server

Use `whisper_manage` inside the running container to inspect and manage the server.

**Show server info:**

```bash
docker exec whisper whisper_manage --showinfo
```

**List available models:**

```bash
docker exec whisper whisper_manage --listmodels
```

**Pre-download a model:**

```bash
docker exec whisper whisper_manage --downloadmodel large-v3-turbo
```

## Switching models

To change the active model:

1. *(Optional but recommended)* Pre-download the new model while the server is running:
   ```bash
   docker exec whisper whisper_manage --downloadmodel large-v3-turbo
   ```

2. Update `WHISPER_MODEL` in your `whisper.env` file (or add `-e WHISPER_MODEL=large-v3-turbo` to your `docker run` command).

3. Restart the container:
   ```bash
   docker restart whisper
   ```

**Available models:**

| Model | Disk | RAM (approx) | Notes |
|---|---|---|---|
| `tiny` | ~75 MB | ~250 MB | Fastest; lower accuracy |
| `tiny.en` | ~75 MB | ~250 MB | English-only |
| `base` | ~145 MB | ~500 MB | Good balance — **default** |
| `base.en` | ~145 MB | ~500 MB | English-only |
| `small` | ~465 MB | ~1.5 GB | Better accuracy |
| `small.en` | ~465 MB | ~1.5 GB | English-only |
| `medium` | ~1.5 GB | ~5 GB | High accuracy |
| `medium.en` | ~1.5 GB | ~5 GB | English-only |
| `large-v2` | ~3 GB | ~10 GB | Very high accuracy |
| `large-v3` | ~3 GB | ~10 GB | Best accuracy |
| `large-v3-turbo` | ~1.6 GB | ~6 GB | Fast + high accuracy ⭐ |

> **Tip:** `large-v3-turbo` offers accuracy close to `large-v3` at roughly half the resource cost. It is the recommended upgrade path from `base` for most production deployments.

RAM figures are approximate and reflect INT8 quantization (default). Models are cached in the `/var/lib/whisper` Docker volume and only downloaded once.

## Using a reverse proxy

For internet-facing deployments, place a reverse proxy in front of Whisper to handle HTTPS termination. The server works without HTTPS on a local or trusted network, but HTTPS is recommended when the API endpoint is exposed to the internet.

Use one of the following addresses to reach the Whisper container from your reverse proxy:

- **`whisper:9000`** — if your reverse proxy runs as a container in the **same Docker network** as Whisper (e.g. defined in the same `docker-compose.yml`).
- **`127.0.0.1:9000`** — if your reverse proxy runs **on the host** and port `9000` is published (the default `docker-compose.yml` publishes it).

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
whisper.example.com {
  reverse_proxy whisper:9000
}
```

**Example with nginx** (reverse proxy on the host):

```nginx
server {
    listen 443 ssl;
    server_name whisper.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Audio files can be large — increase the upload limit as needed
    client_max_body_size 100M;

    location / {
        proxy_pass         http://127.0.0.1:9000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
    }
}
```

Set `WHISPER_API_KEY` in your `env` file when the server is accessible from the public internet.

## Update Docker image

To update the Docker image and container, first [download](#download) the latest version:

```bash
docker pull hwdsl2/whisper-server
```

If the Docker image is already up to date, you should see:

```
Status: Image is up to date for hwdsl2/whisper-server:latest
```

Otherwise, it will download the latest version. Remove and re-create the container:

```bash
docker rm -f whisper
# Then re-run the docker run command from Quick start with the same volume and port.
```

Your downloaded models are preserved in the `whisper-data` volume.

## Technical details

- Base image: `python:3.12-slim` (Debian)
- Runtime: Python 3 (virtual environment at `/opt/venv`)
- STT engine: [faster-whisper](https://github.com/SYSTRAN/faster-whisper) with CTranslate2 (INT8 by default)
- API framework: [FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/)
- Audio decoding: [ffmpeg](https://ffmpeg.org/) (installed from Debian package)
- Data directory: `/var/lib/whisper` (Docker volume)
- Model storage: HuggingFace Hub format inside the volume — downloaded once, reused on restarts

## License

**Note:** The software components inside the pre-built image (such as faster-whisper and its dependencies) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**faster-whisper** is Copyright (C) SYSTRAN, and is distributed under the [MIT License](https://github.com/SYSTRAN/faster-whisper/blob/master/LICENSE).

This project is an independent Docker setup for Whisper and is not affiliated with, endorsed by, or sponsored by OpenAI or SYSTRAN.
