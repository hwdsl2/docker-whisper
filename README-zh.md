[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Whisper 语音转文字 Docker 镜像

[![构建状态](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

使用 [faster-whisper](https://github.com/SYSTRAN/faster-whisper) 在 Docker 容器中运行 [Whisper](https://github.com/openai/whisper) 语音转文字服务器。提供 OpenAI 兼容的音频转录 API。基于 Debian (python:3.12-slim)，简单、私密、可自托管。

**功能特性：**

- OpenAI 兼容的 `POST /v1/audio/transcriptions` 接口 — 任何调用 OpenAI Whisper API 的应用只需修改一行配置即可切换
- 支持所有 Whisper 模型：`tiny`、`base`、`small`、`medium`、`large-v3`、`large-v3-turbo` 等
- 通过辅助脚本 (`whisper_manage`) 管理模型
- 音频数据留在您的服务器上，不发送给第三方
- 支持所有主流音频格式（mp3、m4a、wav、webm、ogg、flac 及 ffmpeg 支持的所有格式）
- 多种响应格式：JSON、纯文本、详细 JSON、SRT 字幕、WebVTT 字幕
- 流式转录 — 添加 `stream=true` 参数，即可通过 SSE 在解码时逐段接收转录结果，无需等待整个文件处理完成
- NVIDIA GPU (CUDA) 加速推理（使用 `:cuda` 镜像标签）
- 离线/隔离网络模式 — 使用预先缓存的模型无需互联网访问 (`WHISPER_LOCAL_ONLY`)
- 通过 [GitHub Actions](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml) 自动构建和发布
- 通过 Docker 数据卷持久化模型缓存
- 多架构支持：`linux/amd64`、`linux/arm64`

**另提供：**

- 不使用 Docker：[Whisper 安装脚本](https://github.com/hwdsl2/whisper-install/blob/main/README-zh.md)
- AI/音频：[WhisperLive（实时 STT）](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh.md)、[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)
- VPN：[WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-zh.md)、[OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-zh.md)、[IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-zh.md)、[Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-zh.md)

**提示：** Whisper、Kokoro、Embeddings 和 LiteLLM 可以[配合使用](#与其他-ai-服务配合使用)，在您自己的服务器上搭建完整的私密 AI 系统。

## Whisper 与 WhisperLive 的选择

| | **docker-whisper** | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh.md) |
|---|---|---|
| **使用场景** | 转录完整音频文件 | 实时麦克风/音频流 |
| **协议** | HTTP REST | WebSocket（流式）+ HTTP REST |
| **延迟** | 完整文件处理后返回结果 | 近实时，逐词输出 |
| **适合** | 会议录音、上传的音频文件 | 浏览器采集、RTSP 流、实时字幕 |
| **镜像大小** | ~180 MB（`:cuda` 约 3 GB） | ~730 MB（`:cuda` 约 4.5 GB） |

## 快速开始

使用以下命令启动 Whisper 服务器：

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

<details>
<summary><strong>GPU 快速开始（NVIDIA CUDA）</strong></summary>

如果您有 NVIDIA GPU，可使用 `:cuda` 镜像进行硬件加速推理：

```bash
docker run \
    --name whisper \
    --restart=always \
    --gpus=all \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    -d hwdsl2/whisper-server:cuda
```

**要求：** NVIDIA GPU、[NVIDIA 驱动](https://www.nvidia.com/en-us/drivers/) 535+，以及主机上已安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。`:cuda` 镜像仅支持 `linux/amd64`。

</details>

**重要：** 此镜像运行默认 `base` 模型需要至少 700 MB 可用内存。内存为 512 MB 或更少的系统不受支持。

**注：** 如需面向互联网的部署，**强烈建议**使用[反向代理](#使用反向代理)来添加 HTTPS。此时，还应将上述 `docker run` 命令中的 `-p 9000:9000` 替换为 `-p 127.0.0.1:9000:9000`，以防止从外部直接访问未加密端口。当服务器可从公网访问时，请在 `env` 文件中设置 `WHISPER_API_KEY`。

首次启动时，Whisper `base` 模型（约 145 MB）将自动下载并缓存。查看日志确认服务器已就绪：

```bash
docker logs whisper
```

看到 "Whisper speech-to-text server is ready" 后，开始转录您的第一个音频文件：

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

**响应：**
```json
{"text": "转录的文字内容显示在这里。"}
```

另外，你也可以在不使用 Docker 的情况下[安装 Whisper](https://github.com/hwdsl2/whisper-install/blob/main/README-zh.md)。如需了解更多关于此镜像的使用方法，请阅读以下各节。

## 系统要求

- 已安装 Docker 的 Linux 服务器（本地或云端）
- 支持的架构：`amd64`（x86_64）、`arm64`（例如 Raspberry Pi 4/5、AWS Graviton）
- 最低内存：默认 `base` 模型约需 700 MB 可用内存（请参阅[模型列表](#切换模型)）
- 首次启动需要访问互联网以下载模型（之后模型将缓存在本地）。使用预先缓存的模型并设置 `WHISPER_LOCAL_ONLY=true` 时不需要网络访问。

**GPU 加速（`:cuda` 镜像）要求：**

- 支持 CUDA 的 NVIDIA GPU（计算能力 6.0+）
- 主机已安装 [NVIDIA 驱动](https://www.nvidia.com/en-us/drivers/) 535 或更高版本
- 已安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- `:cuda` 镜像仅支持 `linux/amd64`

如需面向公网部署，请参阅[使用反向代理](#使用反向代理)以启用 HTTPS。

## 下载

从 [Docker Hub](https://hub.docker.com/r/hwdsl2/whisper-server/) 获取可信构建：

```bash
docker pull hwdsl2/whisper-server
```

如需 NVIDIA GPU 加速，请拉取 `:cuda` 标签：

```bash
docker pull hwdsl2/whisper-server:cuda
```

也可从 [Quay.io](https://quay.io/repository/hwdsl2/whisper-server) 下载：

```bash
docker pull quay.io/hwdsl2/whisper-server
docker image tag quay.io/hwdsl2/whisper-server hwdsl2/whisper-server
```

支持平台：`linux/amd64` 和 `linux/arm64`。`:cuda` 标签仅支持 `linux/amd64`。

## 环境变量

所有变量均为可选。如未设置，将自动使用安全的默认值。

此 Docker 镜像使用以下变量，可在 `env` 文件中声明（参见[示例](whisper.env.example)）：

| 变量 | 说明 | 默认值 |
|---|---|---|
| `WHISPER_MODEL` | 使用的 Whisper 模型。请参阅[模型列表](#切换模型)。 | `base` |
| `WHISPER_LANGUAGE` | 默认转录语言。使用 BCP-47 语言代码（如 `zh`、`en`、`ja`）或 `auto` 自动检测。 | `auto` |
| `WHISPER_PORT` | API 的 HTTP 端口（1–65535）。 | `9000` |
| `WHISPER_DEVICE` | 计算设备：`cpu`、`cuda` 或 `auto`。使用 `:cuda` 镜像时设为 `cuda` 以启用 GPU 加速。`auto` 自动检测 GPU，无 GPU 时回退到 CPU。 | `cpu` |
| `WHISPER_COMPUTE_TYPE` | 量化 / 计算类型。CPU 推荐 `int8`；CUDA 推荐 `float16`。 | `int8`（CPU）/ `float16`（CUDA） |
| `WHISPER_THREADS` | 推理使用的 CPU 线程数。设为物理核心数可获得最佳延迟。 | `2` |
| `WHISPER_API_KEY` | 可选的 Bearer 令牌。设置后所有请求须包含 `Authorization: Bearer <key>`。 | *（未设置）* |
| `WHISPER_LOG_LEVEL` | 日志级别：`DEBUG`、`INFO`、`WARNING`、`ERROR`、`CRITICAL`。 | `INFO` |
| `WHISPER_BEAM` | 转录解码的 beam 大小。较大的值可能以速度换取精度。使用 `1` 可获得最快的贪婪解码。 | `5` |
| `WHISPER_LOCAL_ONLY` | 设为任意非空值（如 `true`）时，禁止所有 HuggingFace 模型下载。适用于预先缓存模型的离线或隔离网络部署。 | *（未设置）* |

**注：** 在 `env` 文件中，值可用单引号括起，例如 `VAR='value'`。`=` 两侧不要有空格。如更改 `WHISPER_PORT`，请相应更新 `docker run` 命令中的 `-p` 参数。

使用 `env` 文件的示例：

```bash
cp whisper.env.example whisper.env
# 编辑 whisper.env 配置您的设置，然后：
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -v ./whisper.env:/whisper.env:ro \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

`env` 文件以绑定挂载方式传入容器，每次重启时自动生效，无需重建容器。

也可通过 `--env-file` 传入：

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    --env-file=whisper.env \
    -d hwdsl2/whisper-server
```

## 使用 docker-compose

```bash
cp whisper.env.example whisper.env
# 按需编辑 whisper.env，然后：
docker compose up -d
docker logs whisper
```

示例 `docker-compose.yml`（已包含在项目中）：

```yaml
services:
  whisper:
    image: hwdsl2/whisper-server
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"  # 如使用主机反向代理，改为 "127.0.0.1:9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      - ./whisper.env:/whisper.env:ro

volumes:
  whisper-data:
```

**注：** 如需面向公网部署，强烈建议使用[反向代理](#使用反向代理)启用 HTTPS。此时请将 `docker-compose.yml` 中的 `"9000:9000/tcp"` 改为 `"127.0.0.1:9000:9000/tcp"`，以防止未加密端口被直接访问。当服务器可从公网访问时，请在 `env` 文件中设置 `WHISPER_API_KEY`。

<details>
<summary><strong>使用 docker-compose 部署 GPU（NVIDIA CUDA）</strong></summary>

项目提供了单独的 `docker-compose.cuda.yml` 用于 GPU 部署：

```bash
cp whisper.env.example whisper.env
# 按需编辑 whisper.env，然后：
docker compose -f docker-compose.cuda.yml up -d
docker logs whisper
```

示例 `docker-compose.cuda.yml`（已包含在项目中）：

```yaml
services:
  whisper:
    image: hwdsl2/whisper-server:cuda
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"  # 如使用主机反向代理，改为 "127.0.0.1:9000:9000/tcp"
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

## API 参考

该 API 与 [OpenAI 音频转录接口](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create)完全兼容。任何已调用 `https://api.openai.com/v1/audio/transcriptions` 的应用，只需设置以下环境变量即可切换到自托管服务：

```
OPENAI_BASE_URL=http://您的服务器IP:9000
```

### 转录音频

```
POST /v1/audio/transcriptions
Content-Type: multipart/form-data
```

**参数：**

| 参数 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `file` | 文件 | ✅ | 音频文件。支持格式：`mp3`、`mp4`、`m4a`、`wav`、`webm`、`ogg`、`flac` 及 ffmpeg 支持的所有格式。 |
| `model` | 字符串 | ✅ | 传入 `whisper-1`（值被接受，但始终使用当前活跃模型）。 |
| `language` | 字符串 | — | BCP-47 语言代码。覆盖本次请求的 `WHISPER_LANGUAGE` 设置。 |
| `prompt` | 字符串 | — | 可选文本，用于引导模型风格或延续前一段内容。 |
| `response_format` | 字符串 | — | 输出格式，默认为 `json`。请参阅[响应格式](#响应格式)。`stream=true` 时忽略此参数。 |
| `temperature` | 浮点数 | — | 采样温度（0–1），默认为 `0`。 |
| `stream` | 布尔值 | — | 启用 SSE 流式传输。为 `true` 时，段落将在解码时以 `text/event-stream` 事件形式返回。默认为 `false`。 |

**示例：**

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -F file=@meeting.m4a \
    -F model=whisper-1 \
    -F language=zh
```

使用 API 密钥认证：

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer your_api_key" \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

### 响应格式

| `response_format` | 说明 |
|---|---|
| `json` | `{"text": "..."}` — 默认，与 OpenAI 基础响应格式一致 |
| `text` | 纯文本，无 JSON 封装 |
| `verbose_json` | 完整 JSON，包含语言、时长、逐段时间戳及对数概率 |
| `srt` | SubRip 字幕格式（`.srt`） |
| `vtt` | WebVTT 字幕格式（`.vtt`） |

**示例 — 流式接收解码段落：**

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -F file=@long-audio.mp3 \
    -F model=whisper-1 \
    -F stream=true
```

**SSE 响应**（每个段落一个事件，最后一个为 `done` 事件）：

```
data: {"type":"segment","start":0.0,"end":2.4,"text":"您好，最近怎么样？"}

data: {"type":"segment","start":2.8,"end":5.1,"text":"我很好，谢谢。"}

data: {"type":"done","text":"您好，最近怎么样？ 我很好，谢谢。"}
```

上传后第一个段落通常在 1–3 秒内到达。每个 `segment` 事件包含以秒为单位的 `start`/`end` 时间戳。最后的 `done` 事件包含与标准 `json` 响应等效的完整转录文本。

**示例 — 通过浏览器 `fetch` 进行流式传输：**

```javascript
const form = new FormData();
form.append("file", audioBlob, "audio.webm");
form.append("model", "whisper-1");
form.append("stream", "true");

const res = await fetch("http://您的服务器IP:9000/v1/audio/transcriptions", {
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

**示例 — 获取 SRT 字幕：**

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -F file=@video.mp4 \
    -F model=whisper-1 \
    -F response_format=srt
```

**示例 — 带时间戳的详细 JSON：**

```bash
curl http://您的服务器IP:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1 \
    -F response_format=verbose_json
```

### 列出模型

```
GET /v1/models
```

返回 OpenAI 兼容格式的当前活跃模型。

```bash
curl http://您的服务器IP:9000/v1/models
```

### 交互式 API 文档

可在以下地址访问交互式 Swagger UI：

```
http://您的服务器IP:9000/docs
```

## 持久化数据

所有服务器数据存储在 Docker 数据卷（容器内的 `/var/lib/whisper`）中：

```
/var/lib/whisper/
├── models--Systran--faster-whisper-*/   # 缓存的 Whisper 模型文件（从 HuggingFace 下载）
├── .port                 # 当前端口（供 whisper_manage 使用）
├── .model                # 当前模型名称（供 whisper_manage 使用）
└── .server_addr          # 缓存的服务器 IP（供 whisper_manage 使用）
```

请备份 Docker 数据卷以保留已下载的模型。模型文件较大（145 MB – 3 GB），首次启动时下载可能需要数分钟；保留数据卷可避免在重建容器时重新下载。

**提示：** `/var/lib/whisper` 数据卷与 `docker-whisper-live` 的 `/var/lib/whisper-live` 数据卷使用相同的 HuggingFace 缓存布局。如果已通过 `docker-whisper-live` 下载了模型，可绑定挂载相同的数据卷目录以避免重复下载。

## 管理服务器

在运行中的容器内使用 `whisper_manage` 来查看和管理服务器。

**显示服务器信息：**

```bash
docker exec whisper whisper_manage --showinfo
```

**列出可用模型：**

```bash
docker exec whisper whisper_manage --listmodels
```

**预先下载模型：**

```bash
docker exec whisper whisper_manage --downloadmodel large-v3-turbo
```

## 切换模型

要更换活跃模型：

1. *（可选但建议）* 在服务器运行时预先下载新模型：
   ```bash
   docker exec whisper whisper_manage --downloadmodel large-v3-turbo
   ```

2. 在 `whisper.env` 文件中更新 `WHISPER_MODEL`（或在 `docker run` 命令中添加 `-e WHISPER_MODEL=large-v3-turbo`）。

3. 重启容器：
   ```bash
   docker restart whisper
   ```

**可用模型：**

| 模型 | 磁盘占用 | 内存（约） | 说明 |
|---|---|---|---|
| `tiny` | ~75 MB | ~250 MB | 最快；精度较低 |
| `tiny.en` | ~75 MB | ~250 MB | 仅英语 |
| `base` | ~145 MB | ~700 MB | 良好平衡 — **默认** |
| `base.en` | ~145 MB | ~700 MB | 仅英语 |
| `small` | ~465 MB | ~1.5 GB | 更高精度 |
| `small.en` | ~465 MB | ~1.5 GB | 仅英语 |
| `medium` | ~1.5 GB | ~5 GB | 高精度 |
| `medium.en` | ~1.5 GB | ~5 GB | 仅英语 |
| `large-v1` | ~3 GB | ~10 GB | 旧版大型模型 |
| `large-v2` | ~3 GB | ~10 GB | 非常高精度 |
| `large-v3` | ~3 GB | ~10 GB | 最高精度 |
| `large-v3-turbo` | ~1.6 GB | ~6 GB | 高速 + 高精度 ⭐ |
| `turbo` | ~1.6 GB | ~6 GB | `large-v3-turbo` 的别名 |

> **提示：** `large-v3-turbo` 的精度接近 `large-v3`，但资源消耗约为其一半。对于大多数生产部署，这是从 `base` 升级的推荐选择。

内存数据为近似值，基于 INT8 量化（默认）。模型缓存在 `/var/lib/whisper` Docker 数据卷中，仅需下载一次。

## 使用反向代理

如需面向公网部署，可在 Whisper 前置反向代理处理 HTTPS 终止。在本地或可信网络中使用无需 HTTPS，但将 API 端点暴露在公网时建议启用 HTTPS。

从反向代理访问 Whisper 容器时使用以下地址之一：

- **`whisper:9000`** — 如果反向代理作为容器运行在与 Whisper **同一 Docker 网络**中（例如定义在同一 `docker-compose.yml` 中）。
- **`127.0.0.1:9000`** — 如果反向代理运行在**主机上**且端口 `9000` 已发布（默认 `docker-compose.yml` 会发布该端口）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 镜像](https://hub.docker.com/_/caddy)）的示例**（自动 Let's Encrypt TLS，反向代理在同一 Docker 网络中）：

`Caddyfile`：
```
whisper.example.com {
  reverse_proxy whisper:9000
}
```

**使用 nginx 的示例**（反向代理运行在主机上）：

```nginx
server {
    listen 443 ssl;
    server_name whisper.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # 音频文件可能较大——按需调整上传限制
    client_max_body_size 100M;

    location / {
        proxy_pass         http://127.0.0.1:9000;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;       # 流式传输（SSE）所需
        proxy_read_timeout 300s;
    }
}
```

如服务器对公网开放，请在 `env` 文件中设置 `WHISPER_API_KEY`。

## 更新 Docker 镜像

如需更新 Docker 镜像和容器，首先[下载](#下载)最新版本：

```bash
docker pull hwdsl2/whisper-server
```

如果镜像已是最新版本，您将看到：

```
Status: Image is up to date for hwdsl2/whisper-server:latest
```

否则将下载最新版本。删除并重新创建容器：

```bash
docker rm -f whisper
# 然后使用相同的数据卷和端口重新运行快速开始中的 docker run 命令。
```

您下载的模型将保留在 `whisper-data` 数据卷中。

## 与其他 AI 服务配合使用

[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)、[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)、[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) 和 [Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md) 镜像可以组合使用，在您自己的服务器上搭建完整的私密 AI 系统——从语音输入/输出到检索增强生成（RAG）。所有这些服务均完全在本地运行。当使用 LiteLLM 连接外部提供商（如 OpenAI、Anthropic）时，您的数据将发送给这些提供商。

```mermaid
graph LR
    D["📄 文档"] -->|向量化| E["Embeddings<br/>(文本转向量)"]
    E -->|存储| VDB["向量数据库<br/>(Qdrant, Chroma)"]
    A["🎤 语音输入"] -->|转录| W["Whisper<br/>(语音转文本)"]
    W -->|查询| E
    VDB -->|上下文| L["LiteLLM<br/>(AI 网关)"]
    W -->|文本| L
    L -->|响应| T["Kokoro TTS<br/>(文本转语音)"]
    T --> B["🔊 语音输出"]
```

| 服务 | 功能 | 默认端口 |
|---|---|---|
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)** | 通过 REST API 转录完整音频文件 | `9000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)** | 将文本转换为向量，用于语义搜索和 RAG | `8000` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | AI 网关——将请求路由至 OpenAI、Anthropic、Ollama 及 100+ 其他提供商 | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)** | 将文本转换为自然语音 | `8880` |

### 语音对话示例

将语音问题转录为文本，从大型语言模型获取回答，并转换为语音输出：

```bash
# 第一步：将语音音频转录为文本（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@question.mp3 -F model=whisper-1 | jq -r .text)

# 第二步：将文本发送给大型语言模型并获取响应（LiteLLM）
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-4o\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 第三步：将响应转换为语音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

### RAG 检索增强生成示例

对文档进行向量化以实现语义检索，并将检索到的上下文发送给大型语言模型进行问答：

```bash
# 第一步：对文档片段进行向量化并存入向量数据库
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 将返回的向量连同原文一起存入 Qdrant、Chroma、pgvector 等向量数据库。

# 第二步：查询时，对问题进行向量化并从向量数据库检索最相关的文档片段，
#          然后将问题和检索到的上下文发送给 LiteLLM 以获取 LLM 回答。
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer <your-litellm-key>" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "gpt-4o",
      "messages": [
        {"role": "system", "content": "请仅根据所提供的上下文进行回答。"},
        {"role": "user", "content": "Docker 的作用是什么？\n\n上下文：Docker 通过将应用打包为容器来简化部署流程。"}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

## 技术细节

- 基础镜像：`:latest` 使用 `python:3.12-slim`（Debian）；`:cuda` 使用 `nvidia/cuda:12.9.1-cudnn-runtime-ubuntu24.04`
- 运行时：Python 3（虚拟环境位于 `/opt/venv`）
- STT 引擎：[faster-whisper](https://github.com/SYSTRAN/faster-whisper) + CTranslate2（CPU 默认 INT8，CUDA 默认 FP16）
- API 框架：[FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/)
- 音频解码：[PyAV](https://github.com/PyAV-Org/PyAV)（内置 FFmpeg 库）
- 数据目录：`/var/lib/whisper`（Docker 数据卷）
- 模型存储：HuggingFace Hub 格式，存储在数据卷中——下载一次，重启后复用

## 授权协议

**注：** 预构建镜像中包含的软件组件（如 faster-whisper 及其依赖项）均受各自版权持有者所选许可证约束。使用预构建镜像时，用户有责任确保其使用方式符合镜像内所有软件的相关许可证要求。

版权所有 (C) 2026 Lin Song   
本作品采用 [MIT 许可证](https://opensource.org/licenses/MIT)授权。

**faster-whisper** 版权归 SYSTRAN 所有，依据 [MIT 许可证](https://github.com/SYSTRAN/faster-whisper/blob/master/LICENSE)分发。

本项目是 Whisper 的独立 Docker 封装，与 OpenAI 或 SYSTRAN 无关联，未获其背书或赞助。
