[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Whisper — распознавание речи на Docker

[![Статус сборки](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml/badge.svg)](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

Docker-образ для запуска сервера распознавания речи [Whisper](https://github.com/openai/whisper) на базе [faster-whisper](https://github.com/SYSTRAN/faster-whisper). Предоставляет совместимый с OpenAI API для транскрибирования аудио. Основан на Debian (python:3.12-slim). Простой, приватный, для самостоятельного развёртывания.

- Совместимый с OpenAI эндпоинт `POST /v1/audio/transcriptions` — любое приложение, использующее OpenAI Whisper API, переключается с изменением одной строки
- Поддержка всех моделей Whisper: `tiny`, `base`, `small`, `medium`, `large-v3`, `large-v3-turbo` и других
- Управление моделями через вспомогательный скрипт (`whisper_manage`)
- Аудиоданные остаются на вашем сервере — никакие данные не отправляются третьим сторонам
- Поддержка всех популярных аудиоформатов (mp3, m4a, wav, webm, ogg, flac и всех форматов ffmpeg)
- Несколько форматов ответа: JSON, простой текст, подробный JSON, субтитры SRT, субтитры WebVTT
- Офлайн-режим — работа без доступа к интернету с предварительно кэшированными моделями (`WHISPER_LOCAL_ONLY`)
- Автоматически собирается и публикуется через [GitHub Actions](https://github.com/hwdsl2/docker-whisper/actions/workflows/main.yml)
- Постоянный кэш моделей через Docker-том
- Поддержка нескольких архитектур: `linux/amd64`, `linux/arm64`

**Также доступно:** Docker-образы для [LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md), [WireGuard](https://github.com/hwdsl2/docker-wireguard/blob/main/README-ru.md), [OpenVPN](https://github.com/hwdsl2/docker-openvpn/blob/main/README-ru.md), [IPsec VPN](https://github.com/hwdsl2/docker-ipsec-vpn-server/blob/master/README-ru.md) и [Headscale](https://github.com/hwdsl2/docker-headscale/blob/main/README-ru.md).

## Быстрый старт

Запустите сервер Whisper следующей командой:

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

**Примечание:** Для развёртываний, доступных из интернета, **настоятельно рекомендуется** добавить HTTPS с помощью [обратного прокси](#использование-обратного-прокси). В этом случае также замените `-p 9000:9000` на `-p 127.0.0.1:9000:9000` в команде `docker run` выше, чтобы исключить прямой доступ к незашифрованному порту извне.

При первом запуске модель Whisper `base` (~145 МБ) автоматически загружается и кэшируется. Проверьте логи, чтобы убедиться в готовности сервера:

```bash
docker logs whisper
```

После появления сообщения "Whisper speech-to-text server is ready" можно начинать транскрибирование:

```bash
curl http://IP_вашего_сервера:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

**Ответ:**
```json
{"text": "Здесь отображается распознанный текст."}
```

## Требования

- Сервер Linux (локальный или облачный) с установленным Docker
- Поддерживаемые архитектуры: `amd64` (x86_64), `arm64` (например, Raspberry Pi 4/5, AWS Graviton)
- Минимум оперативной памяти: ~500 МБ для модели `base` по умолчанию (см. [таблицу моделей](#переключение-моделей))
- Доступ в интернет при первом запуске для загрузки модели (затем модель кэшируется локально). Не требуется при использовании `WHISPER_LOCAL_ONLY=true` с предварительно кэшированными моделями.

Для развёртывания с выходом в интернет см. раздел [Использование обратного прокси](#использование-обратного-прокси) для включения HTTPS.

## Скачать

Получите доверенную сборку из [Docker Hub](https://hub.docker.com/r/hwdsl2/whisper-server/):

```bash
docker pull hwdsl2/whisper-server
```

Либо скачайте из [Quay.io](https://quay.io/repository/hwdsl2/whisper-server):

```bash
docker pull quay.io/hwdsl2/whisper-server
docker image tag quay.io/hwdsl2/whisper-server hwdsl2/whisper-server
```

Поддерживаемые платформы: `linux/amd64` и `linux/arm64`.

## Переменные окружения

Все переменные являются необязательными. Если не заданы, автоматически используются безопасные значения по умолчанию.

Этот Docker-образ использует следующие переменные, которые можно объявить в файле `env` (см. [пример](whisper.env.example)):

| Переменная | Описание | По умолчанию |
|---|---|---|
| `WHISPER_MODEL` | Модель Whisper для использования. См. [таблицу моделей](#переключение-моделей). | `base` |
| `WHISPER_LANGUAGE` | Язык транскрибирования по умолчанию. Код BCP-47 (напр. `ru`, `en`, `zh`) или `auto` для автоопределения. | `auto` |
| `WHISPER_PORT` | HTTP-порт для API (1–65535). | `9000` |
| `WHISPER_DEVICE` | Устройство вычислений для инференса. | `cpu` |
| `WHISPER_COMPUTE_TYPE` | Тип квантования / вычислений. Рекомендуется `int8`. | `int8` |
| `WHISPER_THREADS` | Количество потоков CPU для инференса. Установите значение, равное числу физических ядер, для минимальной задержки. | `2` |
| `WHISPER_API_KEY` | Необязательный Bearer-токен. Если задан, все запросы должны содержать `Authorization: Bearer <key>`. | *(не задан)* |
| `WHISPER_LOG_LEVEL` | Уровень логирования: `DEBUG`, `INFO`, `WARNING`, `ERROR`, `CRITICAL`. | `INFO` |
| `WHISPER_BEAM` | Ширина луча при декодировании транскрипции. Большие значения могут улучшить точность за счёт скорости. Используйте `1` для наиболее быстрого (жадного) декодирования. | `5` |
| `WHISPER_LOCAL_ONLY` | Если задано любое непустое значение (например, `true`), отключает все загрузки моделей с HuggingFace. Для изолированных или офлайн-развёртываний с предварительно кэшированными моделями. | *(не задан)* |

**Примечание:** В файле `env` значения можно заключать в одинарные кавычки, например `VAR='value'`. Не добавляйте пробелы вокруг `=`. Если вы изменяете `WHISPER_PORT`, обновите флаг `-p` в команде `docker run` соответственно.

Пример использования файла `env`:

```bash
cp whisper.env.example whisper.env
# Отредактируйте whisper.env, затем:
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -v ./whisper.env:/whisper.env:ro \
    -p 9000:9000 \
    -d hwdsl2/whisper-server
```

Файл `env` монтируется в контейнер, изменения применяются при каждом перезапуске без пересоздания контейнера.

Либо передайте его через `--env-file`:

```bash
docker run \
    --name whisper \
    --restart=always \
    -v whisper-data:/var/lib/whisper \
    -p 9000:9000 \
    --env-file=whisper.env \
    -d hwdsl2/whisper-server
```

## Использование docker-compose

```bash
cp whisper.env.example whisper.env
# Отредактируйте whisper.env при необходимости, затем:
docker compose up -d
docker logs whisper
```

Пример `docker-compose.yml` (уже включён в проект):

```yaml
services:
  whisper:
    image: hwdsl2/whisper-server
    container_name: whisper
    restart: always
    ports:
      - "9000:9000/tcp"  # Для хостового обратного прокси измените на "127.0.0.1:9000:9000/tcp"
    volumes:
      - whisper-data:/var/lib/whisper
      - ./whisper.env:/whisper.env:ro

volumes:
  whisper-data:
```

**Примечание:** Для развёртывания с выходом в интернет настоятельно рекомендуется использовать [обратный прокси](#использование-обратного-прокси) для добавления HTTPS. В этом случае также измените `"9000:9000/tcp"` на `"127.0.0.1:9000:9000/tcp"` в `docker-compose.yml`, чтобы предотвратить прямой доступ к незашифрованному порту.

## Справочник по API

API полностью совместим с [эндпоинтом транскрибирования OpenAI](https://developers.openai.com/api/reference/resources/audio/subresources/transcriptions/methods/create). Любое приложение, использующее `https://api.openai.com/v1/audio/transcriptions`, может переключиться на собственный хостинг, установив:

```
OPENAI_BASE_URL=http://IP_вашего_сервера:9000
```

### Транскрибирование аудио

```
POST /v1/audio/transcriptions
Content-Type: multipart/form-data
```

**Параметры:**

| Параметр | Тип | Обязателен | Описание |
|---|---|---|---|
| `file` | файл | ✅ | Аудиофайл. Поддерживаемые форматы: `mp3`, `mp4`, `m4a`, `wav`, `webm`, `ogg`, `flac` и все форматы, поддерживаемые ffmpeg. |
| `model` | строка | ✅ | Передайте `whisper-1` (значение принимается, но всегда используется активная модель). |
| `language` | строка | — | Код языка BCP-47. Переопределяет `WHISPER_LANGUAGE` для данного запроса. |
| `prompt` | строка | — | Необязательный текст для управления стилем модели или продолжения предыдущего сегмента. |
| `response_format` | строка | — | Формат вывода. По умолчанию: `json`. См. [форматы ответа](#форматы-ответа). |
| `temperature` | число с плавающей точкой | — | Температура сэмплирования (0–1). По умолчанию: `0`. |

**Пример:**

```bash
curl http://IP_вашего_сервера:9000/v1/audio/transcriptions \
    -F file=@meeting.m4a \
    -F model=whisper-1 \
    -F language=ru
```

С аутентификацией по API-ключу:

```bash
curl http://IP_вашего_сервера:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer your_api_key" \
    -F file=@audio.mp3 \
    -F model=whisper-1
```

### Форматы ответа

| `response_format` | Описание |
|---|---|
| `json` | `{"text": "..."}` — по умолчанию, соответствует базовому ответу OpenAI |
| `text` | Простой текст без обёртки JSON |
| `verbose_json` | Полный JSON с языком, длительностью, временны́ми метками сегментов и логарифмическими вероятностями |
| `srt` | Формат субтитров SubRip (`.srt`) |
| `vtt` | Формат субтитров WebVTT (`.vtt`) |

**Пример — получение субтитров SRT:**

```bash
curl http://IP_вашего_сервера:9000/v1/audio/transcriptions \
    -F file=@video.mp4 \
    -F model=whisper-1 \
    -F response_format=srt
```

**Пример — подробный JSON с временны́ми метками:**

```bash
curl http://IP_вашего_сервера:9000/v1/audio/transcriptions \
    -F file=@audio.mp3 \
    -F model=whisper-1 \
    -F response_format=verbose_json
```

### Список моделей

```
GET /v1/models
```

Возвращает активную модель в совместимом с OpenAI формате.

```bash
curl http://IP_вашего_сервера:9000/v1/models
```

### Интерактивная документация API

Интерактивный Swagger UI доступен по адресу:

```
http://IP_вашего_сервера:9000/docs
```

## Постоянные данные

Все данные сервера хранятся в Docker-томе (`/var/lib/whisper` внутри контейнера):

```
/var/lib/whisper/
├── hub/                  # Кэшированные файлы модели Whisper (скачаны с HuggingFace)
├── .port                 # Активный порт (используется whisper_manage)
├── .model                # Активное название модели (используется whisper_manage)
└── .server_addr          # Кэшированный IP сервера (используется whisper_manage)
```

Создайте резервную копию Docker-тома для сохранения скачанных моделей. Модели занимают значительный объём (145 МБ – 3 ГБ) и могут скачиваться несколько минут при первом запуске; сохранение тома позволяет избежать повторной загрузки при пересоздании контейнера.

## Управление сервером

Используйте `whisper_manage` внутри запущенного контейнера для просмотра информации о сервере и управления им.

**Показать информацию о сервере:**

```bash
docker exec whisper whisper_manage --showinfo
```

**Список доступных моделей:**

```bash
docker exec whisper whisper_manage --listmodels
```

**Предварительная загрузка модели:**

```bash
docker exec whisper whisper_manage --downloadmodel large-v3-turbo
```

## Переключение моделей

Для смены активной модели:

1. *(Необязательно, но рекомендуется)* Предварительно загрузите новую модель, пока сервер работает:
   ```bash
   docker exec whisper whisper_manage --downloadmodel large-v3-turbo
   ```

2. Обновите `WHISPER_MODEL` в файле `whisper.env` (или добавьте `-e WHISPER_MODEL=large-v3-turbo` в команду `docker run`).

3. Перезапустите контейнер:
   ```bash
   docker restart whisper
   ```

**Доступные модели:**

| Модель | Диск | ОЗУ (примерно) | Примечания |
|---|---|---|---|
| `tiny` | ~75 МБ | ~250 МБ | Самая быстрая; низкая точность |
| `tiny.en` | ~75 МБ | ~250 МБ | Только английский |
| `base` | ~145 МБ | ~500 МБ | Хороший баланс — **по умолчанию** |
| `base.en` | ~145 МБ | ~500 МБ | Только английский |
| `small` | ~465 МБ | ~1,5 ГБ | Повышенная точность |
| `small.en` | ~465 МБ | ~1,5 ГБ | Только английский |
| `medium` | ~1,5 ГБ | ~5 ГБ | Высокая точность |
| `medium.en` | ~1,5 ГБ | ~5 ГБ | Только английский |
| `large-v2` | ~3 ГБ | ~10 ГБ | Очень высокая точность |
| `large-v3` | ~3 ГБ | ~10 ГБ | Наивысшая точность |
| `large-v3-turbo` | ~1,6 ГБ | ~6 ГБ | Быстрая + высокая точность ⭐ |

> **Совет:** `large-v3-turbo` обеспечивает точность, близкую к `large-v3`, при вдвое меньшем потреблении ресурсов. Для большинства производственных развёртываний это рекомендуемый вариант обновления с `base`.

Данные по памяти являются приблизительными и учитывают квантование INT8 (по умолчанию). Модели кэшируются в Docker-томе `/var/lib/whisper` и загружаются только один раз.

## Использование обратного прокси

Для развёртывания с выходом в интернет разместите обратный прокси перед Whisper для обработки HTTPS-терминации. Сервер работает без HTTPS в локальной или доверенной сети, но HTTPS рекомендуется при открытом доступе к API-эндпоинту из интернета.

Используйте один из следующих адресов для доступа к контейнеру Whisper из обратного прокси:

- **`whisper:9000`** — если ваш обратный прокси работает как контейнер в **той же Docker-сети**, что и Whisper (например, определён в том же `docker-compose.yml`).
- **`127.0.0.1:9000`** — если ваш обратный прокси работает **на хосте** и порт `9000` опубликован (по умолчанию `docker-compose.yml` публикует его).

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же Docker-сети):

`Caddyfile`:
```
whisper.example.com {
  reverse_proxy whisper:9000
}
```

**Пример с nginx** (обратный прокси на хосте):

```nginx
server {
    listen 443 ssl;
    server_name whisper.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    # Аудиофайлы могут быть большими — увеличьте лимит загрузки при необходимости
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

Установите `WHISPER_API_KEY` в файле `env`, если сервер доступен из публичного интернета.

## Обновление Docker-образа

Для обновления Docker-образа и контейнера сначала [скачайте](#скачать) последнюю версию:

```bash
docker pull hwdsl2/whisper-server
```

Если образ уже актуален, вы увидите:

```
Status: Image is up to date for hwdsl2/whisper-server:latest
```

В противном случае будет скачана последняя версия. Удалите и пересоздайте контейнер:

```bash
docker rm -f whisper
# Затем повторно выполните команду docker run из раздела "Быстрый старт" с теми же томом и портом.
```

Скачанные модели сохранятся в томе `whisper-data`.

## Технические подробности

- Базовый образ: `python:3.12-slim` (Debian)
- Среда выполнения: Python 3 (виртуальное окружение в `/opt/venv`)
- STT-движок: [faster-whisper](https://github.com/SYSTRAN/faster-whisper) + CTranslate2 (INT8 по умолчанию)
- API-фреймворк: [FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/)
- Декодирование аудио: [ffmpeg](https://ffmpeg.org/) (из пакета Debian)
- Директория данных: `/var/lib/whisper` (Docker-том)
- Хранение моделей: формат HuggingFace Hub внутри тома — скачивается один раз, переиспользуется при перезапусках

## Лицензия

**Примечание:** Программные компоненты внутри готового образа (такие как faster-whisper и его зависимости) распространяются под лицензиями, выбранными соответствующими правообладателями. При использовании готового образа пользователь несёт ответственность за соблюдение всех соответствующих лицензий на программное обеспечение, содержащееся в образе.

Copyright (C) 2026 Lin Song   
Данная работа распространяется под [лицензией MIT](https://opensource.org/licenses/MIT).

**faster-whisper** является собственностью SYSTRAN и распространяется под [лицензией MIT](https://github.com/SYSTRAN/faster-whisper/blob/master/LICENSE).

Данный проект представляет собой независимую Docker-обёртку для Whisper и не аффилирован с OpenAI или SYSTRAN, не одобрен и не спонсирован ими.