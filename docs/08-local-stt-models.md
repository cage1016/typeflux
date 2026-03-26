# 本地 STT 模型接入说明

## 当前接入的本地模型

- `Whisper Local`
  - 运行方式：`openai-whisper`
  - 默认模型标识：`small`
  - 说明：适合最稳妥的本地离线转写；模型文件由 Whisper 运行时自行拉取，运行时会一并准备 `ffmpeg` 依赖。

- `SenseVoice Small`
  - 运行方式：`FunASR AutoModel`
  - 默认模型标识：`iic/SenseVoiceSmall`
  - 推荐下载源：`ModelScope`
  - 说明：更适合中文和多语种混合语音，官方仓库同时提供了 ModelScope 生态的模型发布与推理方式。

- `Qwen3-ASR`
  - 运行方式：`qwen-asr`
  - 默认模型标识：`Qwen/Qwen3-ASR-0.6B`
  - 推荐下载源：`ModelScope`
  - 说明：当前实现默认走 CPU 推理，适合作为实验性本地选项；如果后续要追求性能，建议再补充 GPU / vLLM 路径。

## 下载源策略

- 默认优先 `ModelScope`
  - 原因：对中国大陆网络环境更友好；`SenseVoice` 和 `Qwen3-ASR` 的官方说明都直接给出了 ModelScope 下载方式。
- 保留 `Hugging Face`
  - 原因：海外环境更通用；`Qwen3-ASR` 官方同样提供了 Hugging Face 下载方式。
- `Whisper Local`
  - 当前由 `openai-whisper` 自己管理模型下载，不单独走 ModelScope 镜像。

## 业务链路

1. 用户在 `Models -> Voice Transcription` 里选择 `Local Models`
2. 选择具体模型、下载源、模型标识
3. 点击 `Prepare Local Speech Model`
4. 应用自动创建 Python venv、安装运行依赖、下载模型
5. 首次转写时自动拉起本地 FastAPI 服务
6. App 把录音转成 WAV 后上传给本地服务
7. 本地服务返回 OpenAI-compatible 风格的 `{ "text": "..." }` 响应

## 已知限制

- `Qwen3-ASR` 官方文档明显更偏向 CUDA / vLLM 场景；当前 macOS 本地集成默认走 CPU，速度可能较慢。
- `SenseVoice Small` 和 `Qwen3-ASR` 的首次准备过程会安装较多 Python 依赖，时间取决于网络与本机环境。
- 如果后续要进一步优化 Apple Silicon 体验，可以考虑把 `Whisper` 换成 `mlx-whisper`，或者补充 `SenseVoice` 的 ONNX 路径。
