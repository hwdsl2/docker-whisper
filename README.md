[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Whisper Speech-to-Text on Docker

[![Build Status](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT) &nbsp;[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://vpnsetup.net/whisper-notebook)

Docker image to run a [Whisper](https://github.com/openai/whisper) speech-to-text server, powered by [faster-whisper](https://github.com/SYSTRAN/faster-whisper). Provides an OpenAI-compatible audio transcription API. Based on Debian (python:3.12-slim). Designed to be simple, private, and self-hosted.

**Features:**

- OpenAI-compatible `POST /v1/audio/transcriptions` endpoint — any app using the OpenAI Whisper API switches with a one-line change
- Supports all Whisper models: `tiny`, `base`, `small`, `medium`, `large-v3`, `large-v3-turbo` and more
- Model management via a helper script (`whisper_manage`)
- Audio stays on your server — no data sent to third parties
- All major audio formats supported (mp3, m4a, wav, webm, ogg, flac, and all ffmpeg formats)
- Multiple response formats: JSON, plain text, verbose JSON, SRT subtitles, WebVTT subtitles
- Streaming transcription — add `stream=true` to receive segments via SSE as they are decoded, with no waiting for the full file
- NVIDIA GPU (CUDA) acceleration for faster inference (`:cuda` image tag)
- Offline/air-gapped mode — run without internet access using pre-cached models (`WHISPER_LOCAL_ONLY`)
- Automatically built and published via [GitHub Actions](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml)
- Persistent model cache via a Docker volume
- Multi-arch: `linux/amd64`, `linux/arm64`

**Also available:**

- Try it online: [Open in Colab](https://vpnsetup.net/whisper-notebook) — no Docker or installation required
- AI/Audio: [WhisperLive (real-time STT)](https://github.com/hwdsl2/docker-whisper-live), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro), [Embeddings](https://github.com/hwdsl2/docker-embeddings), [LiteLLM](https://github.com/hwdsl2/docker-litellm), [Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)
- VPN: [WireGuard](https://github.com/hwdsl2/docker-wireguard), [OpenVPN](https://github.com/hwdsl2/docker-openvpn), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server), [Headscale](https://github.com/hwdsl2/docker-headscale)
- Tools: [MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)

**Tip:** Whisper, Kokoro, Embeddings, LiteLLM, Ollama, and MCP Gateway can be [used together](#using-with-other-ai-services) to build a complete, private AI stack on your own server.

## When to use Whisper vs. WhisperLive

| | **docker-whisper** | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live) |
|---|---|---|
| **Use case** | Transcribe complete audio files | Live microphone / real-time audio streaming |
| **Protocol** | HTTP REST | WebSocket (streaming) + HTTP REST |
| **Latency** | Full file, then response | Near-real-time, word by word |
| **Best for** | Meeting recordings, uploaded audio | Browser capture, RTSP streams, live captions |
| **Image size** | ~180 MB (~3 GB for `:cuda`) | ~730 MB (~4.5 GB for `:cuda`) |

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

<details>
<summary><strong>GPU quick start (NVIDIA CUDA)</strong></summary>

If you have an NVIDIA GPU, use the `:cuda` image for hardware-accelerated inference:

```bash
docker run \
    --name whisper \
    --restart=always \
    --gpus=all \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    -d hwdsl2/whisper-server:cuda
```

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 535+, and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host. The `:cuda` image is `linux/amd64` only.

</details>

**Important:** This image requires at least 700 MB of available RAM for the default `base` model. Systems with 512 MB or less of RAM are not supported.

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also replace `-p 9000:9000` with `-p 127.0.0.1:9000:9000` in the `docker run` command above, to prevent direct access to the unencrypted port. Set `WHISPER_API_KEY` in your `env` file when the server is accessible from the public internet.

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

Alternatively, you may [set up Whisper without Docker](https://github.com/hwdsl2/whisper-install). To learn more about how to use this image, read the sections below.

## Requirements

- A Linux server (local or cloud) with Docker installed
- Supported architectures: `amd64` (x86_64), `arm64` (e.g. Raspberry Pi 4/5, AWS Graviton)
- Minimum RAM: ~700 MB free for the default `base` model (see [model table](#switching-models))
- Internet access for the initial model download (the model is cached locally afterwards). Not required if using `WHISPER_LOCAL_ONLY=true` with pre-cached models.

**For GPU acceleration (`:cuda` image):**

- NVIDIA GPU with CUDA support (Compute Capability 6.0+)
- [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 535 or later installed on the host
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed
- The `:cuda` image supports `linux/amd64` only

For internet-facing deployments, see [Using a reverse proxy](#using-a-reverse-proxy) to add HTTPS.

## Download

Get the trusted build from the [Docker Hub registry](https://hub.docker.com/r/hwdsl2/whisper-server/):

```bash
docker pull hwdsl2/whisper-server
```

For NVIDIA GPU acceleration, pull the `:cuda` tag instead:

```bash
docker pull hwdsl2/whisper-server:cuda
```

Alternatively, you may download from [Quay.io](https://quay.io/repository/hwdsl2/whisper-server):

```bash
docker pull quay.io/hwdsl2/whisper-server
docker image tag quay.io/hwdsl2/whisper-server hwdsl2/whisper-server
```

Supported platforms: `linux/amd64` and `linux/arm64`. The `:cuda` tag supports `linux/amd64` only.

## Environment variables

All variables are optional. If not set, secure defaults are used automatically.

This Docker image uses the following variables, that can be declared in an `env` file (see [example](whisper.env.example)):

| Variable | Description | Default |
|---|---|---|
| `WHISPER_MODEL` | Whisper model to use. See [model table](#switching-models) for options. | `base` |
| `WHISPER_LANGUAGE` | Default transcription language. BCP-47 code (e.g. `en`, `fr`, `de`, `zh`, `ja`) or `auto` to autodetect. | `auto` |
| `WHISPER_PORT` | HTTP port for the API (1–65535). | `9000` |
| `WHISPER_DEVICE` | Compute device: `cpu`, `cuda`, or `auto`. Use `cuda` with the `:cuda` image for GPU acceleration. `auto` detects GPU and falls back to CPU. | `cpu` |
| `WHISPER_COMPUTE_TYPE` | Quantization / compute type. `int8` is recommended for CPU; `float16` is recommended for CUDA. | `int8` (CPU) / `float16` (CUDA) |
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

<details>
<summary>Alternatively, pass it with <code>--env-file</code></summary>

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    --env-file=whisper.env \
    -d hwdsl2/whisper-server
```

</details>

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

**Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. In that case, also change `"9000:9000/tcp"` to `"127.0.0.1:9000:9000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port. Set `WHISPER_API_KEY` in your `env` file when the server is accessible from the public internet.

<details>
<summary><strong>Using docker-compose with GPU (NVIDIA CUDA)</strong></summary>

A separate `docker-compose.cuda.yml` is provided for GPU deployments:

```bash
cp whisper.env.example whisper.env
# Edit whisper.env as needed, then:
docker compose -f docker-compose.cuda.yml up -d
docker logs whisper
```

Example `docker-compose.cuda.yml` (already included):

```yaml
services:
  whisper:
    image: hwdsl2/whisper-server:cuda
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"  # For a host-based reverse proxy, change to "127.0.0.1:9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      - ./whisper.env:/whisper.env:ro
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]

volumes:
  whisper-data:
```

</details>

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
| `response_format` | string | — | Output format. Default: `json`. See [response formats](#response-formats). Ignored when `stream=true`. |
| `temperature` | float | — | Sampling temperature (0–1). Default: `0`. |
| `stream` | boolean | — | Enable SSE streaming. When `true`, segments are returned as `text/event-stream` events as they are decoded. Default: `false`. |

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

**Example — stream segments as they are decoded:**

```bash
curl http://your_server_ip:9000/v1/audio/transcriptions \
    -F file=@long-audio.mp3 \
    -F model=whisper-1 \
    -F stream=true
```

**SSE response** (one event per segment, then a final `done` event):

```
data: {"type":"segment","start":0.0,"end":2.4,"text":"Hello, how are you?"}

data: {"type":"segment","start":2.8,"end":5.1,"text":"I'm doing well, thank you."}

data: {"type":"done","text":"Hello, how are you? I'm doing well, thank you."}
```

The first segment typically arrives within 1–3 seconds of upload. Each `segment` event includes `start`/`end` timestamps in seconds. The final `done` event contains the full assembled transcript, equivalent to the standard `json` response.

<details>
<summary><strong>Example — stream from a browser using <code>fetch</code></strong></summary>

```javascript
const form = new FormData();
form.append("file", audioBlob, "audio.webm");
form.append("model", "whisper-1");
form.append("stream", "true");

const res = await fetch("http://your_server_ip:9000/v1/audio/transcriptions", {
  method: "POST", body: form,
});

const reader = res.body.getReader();
const decoder = new TextDecoder();
let buffer = "";

while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  buffer += decoder.decode(value, { stream: true });
  // SSE frames are separated by "\n\n"; split and process complete frames
  const frames = buffer.split("\n\n");
  buffer = frames.pop(); // keep any incomplete trailing frame
  for (const frame of frames) {
    if (!frame.startsWith("data: ")) continue;
    const event = JSON.parse(frame.slice(6));
    if (event.type === "segment") console.log(event.text);
    if (event.type === "done") console.log("Full text:", event.text);
  }
}
```

</details>

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
├── models--Systran--faster-whisper-*/   # Cached Whisper model files (downloaded from HuggingFace)
├── .port                 # Active port (used by whisper_manage)
├── .model                # Active model name (used by whisper_manage)
└── .server_addr          # Cached server IP (used by whisper_manage)
```

Back up the Docker volume to preserve downloaded models. Models are large (145 MB – 3 GB) and can take several minutes to download on first start; preserving the volume avoids re-downloading on container recreation.

**Tip:** The `/var/lib/whisper` volume uses the same HuggingFace cache layout as `docker-whisper-live`'s `/var/lib/whisper-live` volume. If you have already downloaded a model with `docker-whisper-live`, you can bind-mount the same volume directory to avoid re-downloading.

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
| `base` | ~145 MB | ~700 MB | Good balance — **default** |
| `base.en` | ~145 MB | ~700 MB | English-only |
| `small` | ~465 MB | ~1.5 GB | Better accuracy |
| `small.en` | ~465 MB | ~1.5 GB | English-only |
| `medium` | ~1.5 GB | ~5 GB | High accuracy |
| `medium.en` | ~1.5 GB | ~5 GB | English-only |
| `large-v1` | ~3 GB | ~10 GB | Older large model |
| `large-v2` | ~3 GB | ~10 GB | Very high accuracy |
| `large-v3` | ~3 GB | ~10 GB | Best accuracy |
| `large-v3-turbo` | ~1.6 GB | ~6 GB | Fast + high accuracy ⭐ |
| `turbo` | ~1.6 GB | ~6 GB | Alias for `large-v3-turbo` |

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
        proxy_http_version 1.1;       # required for chunked streaming (SSE)
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

## Using with other AI services

The [Whisper (STT)](https://github.com/hwdsl2/docker-whisper), [Embeddings](https://github.com/hwdsl2/docker-embeddings), [LiteLLM](https://github.com/hwdsl2/docker-litellm), [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro), [Ollama (LLM)](https://github.com/hwdsl2/docker-ollama), and [MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway) images can be combined to build a complete, private AI stack on your own server — from voice I/O to RAG-powered question answering. Whisper, Kokoro, and Embeddings run fully locally. Ollama runs all LLM inference locally, so no data is sent to third parties. When using LiteLLM with external providers (e.g., OpenAI, Anthropic), your data will be sent to those providers.

```mermaid
graph LR
    D["📄 Documents"] -->|embed| E["Embeddings<br/>(text → vectors)"]
    E -->|store| VDB["Vector DB<br/>(Qdrant, Chroma)"]
    A["🎤 Audio input"] -->|transcribe| W["Whisper<br/>(speech-to-text)"]
    W -->|query| E
    VDB -->|context| L["LiteLLM<br/>(AI gateway)"]
    W -->|text| L
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|response| T["Kokoro TTS<br/>(text-to-speech)"]
    T --> B["🔊 Audio output"]
    L -->|MCP protocol| M["MCP Gateway<br/>(MCP endpoint)"]
    M --> C["🤖 AI assistant<br/>(Claude, Cursor, etc.)"]
```

| Service | Role | Default port |
|---|---|---|
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)** | Transcribes complete audio files via REST API | `9000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | Converts text to vectors for semantic search and RAG | `8000` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway — routes requests to OpenAI, Anthropic, Ollama, and 100+ other providers | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro)** | Converts text to natural-sounding speech | `8880` |
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)** | Exposes AI services as MCP tools for AI assistants (Claude, Cursor, etc.) | `3000` |

<details>
<summary><strong>Voice pipeline example</strong></summary>

Transcribe a spoken question, get an LLM response, and convert it to speech:

```bash
# Step 1: Transcribe audio to text (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# Step 2: Send text to an LLM and get a response (LiteLLM)
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Step 3: Convert the response to speech (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

</details>

<details>
<summary><strong>RAG pipeline example</strong></summary>

Embed documents for semantic search, then retrieve context and answer questions with an LLM:

```bash
# Step 1: Embed a document chunk and store the vector in your vector DB
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Store the returned vector alongside the source text in Qdrant, Chroma, pgvector, etc.

# Step 2: At query time, embed the question, retrieve the top matching chunks from
#          the vector DB, then send the question and retrieved context to LiteLLM.
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": "Answer using only the provided context."},
        {"role": "user", "content": "What does Docker do?\n\nContext: Docker simplifies deployment by packaging apps in containers."}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

</details>


<details>
<summary><strong>Full stack docker-compose example</strong></summary>

Deploy all services with a single command. No setup required — all services auto-configure with secure defaults on first start.

**Resource requirements:** Running all services together requires at least 8 GB of RAM (with small models). For larger LLM models (8B+), 32 GB or more is recommended. You can comment out services you don't need to reduce memory usage.

```yaml
services:
  ollama:
    image: hwdsl2/ollama-server
    container_name: ollama
    restart: always
    # ports:
    #   - "11434:11434/tcp"  # Uncomment for direct access to Ollama
    volumes:
      - ollama-data:/var/lib/ollama
      # - ./ollama.env:/ollama.env:ro  # optional: custom config

  litellm:
    image: hwdsl2/litellm-server
    container_name: litellm
    restart: always
    ports:
      - "4000:4000/tcp"
    environment:
      - LITELLM_OLLAMA_BASE_URL=http://ollama:11434
    volumes:
      - litellm-data:/etc/litellm
      # - ./litellm.env:/litellm.env:ro  # optional: custom config

  embeddings:
    image: hwdsl2/embeddings-server
    container_name: embeddings
    restart: always
    ports:
      - "8000:8000/tcp"
    volumes:
      - embeddings-data:/var/lib/embeddings
      # - ./embed.env:/embed.env:ro  # optional: custom config

  whisper:
    image: hwdsl2/whisper-server
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      # - ./whisper.env:/whisper.env:ro  # optional: custom config

  kokoro:
    image: hwdsl2/kokoro-server
    container_name: kokoro
    restart: always
    ports:
      - "8880:8880/tcp"
    volumes:
      - kokoro-data:/var/lib/kokoro
      # - ./kokoro.env:/kokoro.env:ro  # optional: custom config

  mcp:
    image: hwdsl2/mcp-gateway
    container_name: mcp
    restart: always
    ports:
      - "3000:3000/tcp"
    volumes:
      - mcp-data:/var/lib/mcp
      # - ./mcp.env:/mcp.env:ro  # optional: custom config

volumes:
  ollama-data:
  litellm-data:
  embeddings-data:
  whisper-data:
  kokoro-data:
  mcp-data:
```

For NVIDIA GPU acceleration, change image tags to `:cuda` for ollama, whisper, and kokoro, and add the following to each of those services:

```yaml
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

</details>

## Technical details

- Base image: `python:3.12-slim` (Debian) for `:latest`; `nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04` for `:cuda`
- Runtime: Python 3 (virtual environment at `/opt/venv`)
- STT engine: [faster-whisper](https://github.com/SYSTRAN/faster-whisper) with CTranslate2 (INT8 by default on CPU, FP16 on CUDA)
- API framework: [FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/)
- Audio decoding: [PyAV](https://github.com/PyAV-Org/PyAV) (bundled FFmpeg libraries)
- Data directory: `/var/lib/whisper` (Docker volume)
- Model storage: HuggingFace Hub format inside the volume — downloaded once, reused on restarts

## License

**Note:** The software components inside the pre-built image (such as faster-whisper and its dependencies) are under the respective licenses chosen by their respective copyright holders. As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

**faster-whisper** is Copyright (C) SYSTRAN, and is distributed under the [MIT License](https://github.com/SYSTRAN/faster-whisper/blob/master/LICENSE).

This project is an independent Docker setup for Whisper and is not affiliated with, endorsed by, or sponsored by OpenAI or SYSTRAN.
