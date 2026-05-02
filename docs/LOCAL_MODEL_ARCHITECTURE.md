# Typeflux 本地模型架构详解

> 本文面向对本地模型、语音识别、推理引擎等概念尚不熟悉的读者。如果你已经了解这些基础知识，可以直接跳到 [架构总览](#3-架构总览) 一节。

---

## 1. 为什么要有"本地模型"

Typeflux 的核心体验是：**按住快捷键说话，松手后文字自动插入到你正在使用的 App 中**。

在这条链路里，最关键的一步是 **语音转文字（Speech-to-Text，简称 STT）** —— 把你嘴巴说出来的声音信号，变成屏幕上可以编辑的文字。实现这一步有两条路：

| | 云端转写 | 本地转写 |
|---|---|---|
| 工作方式 | 把音频发到远程服务器，服务器跑模型转写后返回结果 | 在你自己的 Mac 上跑模型，就地完成转写 |
| 优势 | 模型大、精度高、不占本地资源 | 离线可用、免费、速度快、隐私好 |
| 劣势 | 需要网络、可能收费、音频数据要出设备 | 需要本地算力，模型文件需要下载或内置 |

Typeflux 两条路都支持。本文专门讲解 **本地转写** 这条路的实现。

一句话总结：**本地模型 = 把"听懂你说的话"这件事，在你自己的电脑上完成，不经过任何服务器。**

---

## 2. 两个最容易混淆的概念：运行时 vs 模型

初学者最容易搞混的，就是"运行时"和"模型"这两个词。用一个类比来说明：

> **运行时 = 播放器（比如 VLC）**
> **模型 = 电影文件（比如一个 .mkv）**

- **播放器** 知道怎么解码视频、怎么渲染画面、怎么输出声音。但它自己不包含任何电影内容——你给它不同的电影文件，它就播放不同的电影。

- **电影文件** 包含了实际的影像内容。但它自己不会"播放"——你必须用一个播放器去打开它。

在语音识别的世界里：

- **运行时（Runtime）** 是一个推理引擎，它知道怎么把音频数据喂给模型、怎么执行计算、怎么拿到结果。它本身不包含任何"语音知识"。
- **模型（Model）** 是一堆训练好的神经网络权重文件（本质上是巨大的数字矩阵）。它存储了"听到什么声音 → 应该输出什么文字"的所有经验。

两者独立下载、独立存储。Typeflux 在需要的时候把它们组合起来工作。

---

## 3. 架构总览

Typeflux 支持五个本地模型，背后是两套完全不同的运行时：

```
                         STTRouter（路由层）
                              │
                              ▼
                     LocalModelTranscriber（本地转写总控）
                       │                │
                       ▼                ▼
              ┌─ WhisperKit 运行时 ─┐   ┌─ Sherpa-ONNX 运行时 ─┐
              │  (Apple CoreML)     │   │  (ONNX Runtime)       │
              │                     │   │                       │
              │  ● whisperLocal     │   │  ● senseVoiceSmall    │
              │  ● whisperLocalLarge│   │  ● qwen3ASR           │
              └─────────────────────┘   │  ● funASR             │
                                        └───────────────────────┘
```

下面分别展开。

---

## 4. 运行时 A：WhisperKit（苹果原生方案）

### 它是什么

WhisperKit 是开源社区 [Argmax](https://github.com/argmaxinc/WhisperKit) 开发的一个 Swift 库。它把 OpenAI 开源的 **Whisper** 语音识别模型转换成了苹果的 CoreML 格式，可以直接在 Apple Silicon 芯片的 **Neural Engine（神经引擎）** 上高速运行。

### 模型文件长什么样

WhisperKit 的模型是一组 CoreML 编译后的目录：

```
whisperkit-medium/
├── MelSpectrogram.mlmodelc/    ← 音频频谱分析组件
│   ├── model.mlmodel
│   └── weights/weight.bin
├── AudioEncoder.mlmodelc/      ← 音频特征编码组件
│   ├── model.mlmodel
│   └── weights/weight.bin
└── TextDecoder.mlmodelc/       ← 文字解码组件
    ├── model.mlmodel
    └── weights/weight.bin
```

这三个组件构成了一条流水线：

1. **MelSpectrogram（梅尔频谱）**：把原始音频波形转换成一种"频谱图"——横轴是时间，纵轴是频率，颜色深浅表示能量大小。这是语音识别的标准输入格式。
2. **AudioEncoder（音频编码器）**：读取频谱图，提取出有意义的语音特征向量。可以理解为"听出了这段声音里说了什么音素、什么语调"。
3. **TextDecoder（文字解码器）**：根据特征向量，一个字一个字地生成最终的文字输出。

### 工作方式

WhisperKit 是**进程内**运行的——它的代码直接编译进 Typeflux 的主进程：

```
Typeflux 进程
  ├── 你的 App 逻辑
  └── WhisperKit 库
       └── CoreML 推理（在 Neural Engine / GPU / CPU 上执行）
```

- **优势**：可以拿到流式进度回调（边跑边显示部分结果），延迟低。
- **代价**：medium 模型约 1.5GB，large-v3 约 3GB。加载到内存后非常吃资源。
- **适用场景**：对转写质量要求高、Mac 内存充足的情况。

### 代码中的关键类型

| 类型 | 职责 |
|------|------|
| `WhisperKitTranscriber` | 封装 WhisperKit 库的调用，负责创建 pipeline 和执行转写 |
| `LocalModelTranscriber` | 本地转写的总控，内部维护一个 `whisperKitCache` 缓存已加载的 WhisperKit 实例 |

缓存策略：WhisperKit 实例按 `"模型名|模型路径"` 作为 key 缓存。开启内存优化后，30 分钟不使用会自动释放；关闭内存优化则常驻内存。

---

## 5. 运行时 B：Sherpa-ONNX（跨平台方案）

### 它是什么

Sherpa-ONNX 是 [k2-fsa](https://github.com/k2-fsa/sherpa-onnx) 项目开发的语音处理工具包，底层使用微软的 **ONNX Runtime** 作为推理引擎。它提供了一个命令行程序 `sherpa-onnx-offline`，你把音频文件喂给它，它吐出转写文字。

### "量化"是什么意思

你会注意到模型文件名里有 `int8` 字样（如 `model.int8.onnx`）。这是 **量化（Quantization）** 的意思：

- 神经网络的权重本来是 32 位浮点数（float32），一个数字占 4 字节。
- **int8 量化** 把它压缩成 8 位整数，只占 1 字节。
- 效果：**模型体积缩小约 4 倍，精度损失通常在 1-2% 以内**。

这就是 SenseVoice 模型只有 47MB 而 Whisper medium 要 1.5GB 的主要原因之一。

### 模型文件长什么样

不同模型的文件结构略有不同：

**SenseVoice Small（47MB，默认模型）：**
```
sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/
├── model.int8.onnx      ← 量化后的神经网络权重
└── tokens.txt            ← 词表（模型能识别的字和词）
```

**Qwen3-ASR 0.6B（Qwen 语音模型）：**
```
sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/
├── conv_frontend.onnx    ← 音频前端卷积网络
├── encoder.int8.onnx     ← 编码器
├── decoder.int8.onnx     ← 解码器
└── tokenizer/
    ├── merges.txt        ← BPE 分词的合并规则
    ├── tokenizer_config.json
    └── vocab.json         ← 词表
```

**FunASR / Paraformer：**
```
sherpa-onnx-paraformer-zh-small-2024-03-09/
├── model.int8.onnx
└── tokens.txt
```

### 工作方式

Sherpa-ONNX 是**进程外**运行的——Typeflux 会启动一个独立的子进程来执行转写：

```
Typeflux 进程                    子进程
  │                                │
  │  1. 把音频转成 WAV 格式         │
  │  2. spawn Process              │
  │ ──────────────────────────────▶│  sherpa-onnx-offline
  │                                │    --sense-voice-model=model.int8.onnx
  │                                │    --tokens=tokens.txt
  │                                │    audio.wav
  │  3. 读取 stdout 输出            │
  │ ◀──────────────────────────────│  → 输出转写文字
  │  4. 子进程退出，内存释放         │
```

- **优势**：模型跑完即释放内存，不占用主进程资源；进程崩溃不影响主 App。
- **代价**：没有中间进度反馈，只能等全部完成。
- **适用场景**：日常快速语音输入（按住说话松开插入），响应速度比绝对精度更重要。

### 代码中的关键类型

| 类型 | 职责 |
|------|------|
| `SherpaOnnxCommandLineDecoder` | 底层通用解码器：准备参数、启动子进程、解析 stdout 输出 |
| `SenseVoiceTranscriber` | SenseVoice 专用包装，设置 `--sense-voice-*` 系列参数 |
| `Qwen3ASRTranscriber` | Qwen3-ASR 专用包装，设置 `--qwen3-asr-*` 系列参数 |
| `FunASRTranscriber` | FunASR/Paraformer 专用包装，设置 `--paraformer` 参数 |
| `AudioFileTranscoder` | 音频格式转换：把各种格式统一转成 16-bit PCM WAV |

---

## 6. "CoreML" 和 "ONNX" 是什么

这两个词是两种**模型文件格式标准**：

| 格式 | 主导方 | 特点 |
|------|--------|------|
| **CoreML** | Apple | 苹果平台专用，能利用 Neural Engine 硬件加速，只能在 macOS/iOS 上跑 |
| **ONNX** | 微软（开源社区维护） | 跨平台标准，Windows/Linux/macOS 都能跑，不一定能用专用硬件 |

打个比方：CoreML 就像 `.mov` 格式（苹果生态优化），ONNX 就像 `.mp4` 格式（到处都能放）。模型训练完成后，需要转换成特定格式才能在对应的运行时中运行。

---

## 7. 运行时二进制文件：Sherpa-ONNX 的"引擎包"

Sherpa-ONNX 作为进程外方案，需要一组可执行文件才能工作。Typeflux 使用的运行时包是 `sherpa-onnx-v1.13.0-osx-universal2-shared-no-tts`，包含：

```
sherpa-onnx-v1.13.0-osx-universal2-shared-no-tts/
├── bin/
│   └── sherpa-onnx-offline      ← 主程序（接收音频，输出文字）
└── lib/
    ├── libsherpa-onnx-c-api.dylib      ← Sherpa-ONNX 核心库
    ├── libonnxruntime.dylib             ← ONNX Runtime 推理引擎
    └── libonnxruntime.1.24.4.dylib      ← ONNX Runtime 版本库
```

- `sherpa-onnx-offline` 是实际执行推理的命令行工具
- 动态库（`.dylib`）提供推理所需的底层运算支持
- `osx-universal2` 表示同时支持 Intel 和 Apple Silicon Mac
- `no-tts` 表示不包含文本转语音功能（Typeflux 只需要语音转文字）

这些文件可以**从网上下载**，也可以**内置在 .app 包里**（见第 9 节）。

---

## 8. 文件存储布局

所有本地模型相关文件统一存放在 `~/Library/Application Support/Typeflux/LocalModels/` 下：

```
~/Library/Application Support/Typeflux/LocalModels/
├── senseVoiceSmall/
│   └── sensevoice-small/
│       ├── sherpa-onnx-v1.13.0-osx-universal2-shared-no-tts/   ← 运行时
│       │   ├── bin/sherpa-onnx-offline
│       │   └── lib/*.dylib
│       ├── sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/  ← 模型
│       │   ├── model.int8.onnx
│       │   └── tokens.txt
│       └── prepared.json                                         ← 就绪标记
│
├── qwen3ASR/
│   └── <identifier>/
│       ├── sherpa-onnx-v1.13.0-.../                             ← 运行时（可能共享）
│       ├── sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/          ← 模型
│       └── prepared.json
│
├── whisperLocal/
│   └── <identifier>/
│       ├── MelSpectrogram.mlmodelc/
│       ├── AudioEncoder.mlmodelc/
│       ├── TextDecoder.mlmodelc/
│       └── prepared.json
│
└── ...（其他模型同理）
```

每个模型目录下的 `prepared.json` 记录了这个模型的元信息：

```json
{
    "model": "senseVoiceSmall",
    "modelIdentifier": "sensevoice-small",
    "storagePath": "/Users/you/Library/Application Support/Typeflux/LocalModels/senseVoiceSmall/sensevoice-small",
    "source": "huggingFace",
    "preparedAt": "2026-05-02T10:30:00Z"
}
```

App 在使用模型前会检查这个文件——如果存在且路径有效，说明模型已就绪；否则触发下载。

---

## 9. 内置（Bundled）模型机制

App 构建时可以选择两个变体：

| 变体 | 内置内容 | 首次使用体验 | 安装包大小 |
|------|----------|-------------|-----------|
| **Minimal** | 仅内置 Sherpa-ONNX 运行时二进制文件 | 首次使用时需要下载模型文件（约 47MB） | 较小 |
| **Full** | 运行时 + SenseVoice 模型文件全部内置 | 开箱即用，无需下载 | 较大 |

内置的文件放在 `.app` 包内：

```
Typeflux.app/Contents/Resources/
├── BundledModels/
│   └── senseVoiceSmall/
│       └── sensevoice-small/
│           ├── sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/  ← 内置模型
│           └── sherpa-onnx-v1.13.0-.../ → 符号链接到 LocalRuntimes
└── LocalRuntimes/
    └── sherpa-onnx-v1.13.0-osx-universal2-shared-no-tts/            ← 内置运行时
        ├── bin/sherpa-onnx-offline
        └── lib/*.dylib
```

App 启动时，`BundledLocalModelLocator` 会在三个候选路径中搜索内置模型。找到后，`LocalModelManager` 会创建一个**符号链接（symlink）**，把内置模型链接到 `LocalModels/` 目录下。这样所有下游代码都统一用同一个路径查找，不需要区分"内置的"还是"下载的"。

---

## 10. 模型下载机制

当用户选择的模型不在本地时，Typeflux 会自动下载。

### 下载源选择

每个模型都有两个下载源：

| 源 | 地址 | 适用场景 |
|----|------|----------|
| **HuggingFace** | `huggingface.co` | 国际用户，默认选择 |
| **中国镜像** | `hf-mirror.com` / ModelScope | 国内用户，速度更快 |

`NetworkLocalModelDownloadSourceResolver` 会**同时探测所有源的延迟**（用 HEAD 请求），然后按响应速度排序，优先使用最快的源。

### 自动下载（AutoModelDownloadService）

除了用户主动选择触发的下载，Typeflux 还有一套后台自动下载机制：

- **触发时机**：App 启动时，以及用户开启"本地优化"设置时
- **默认目标**：SenseVoice Small（无论 CPU 架构，因为它最轻量）
- **重试策略**：指数退避 —— 立即重试 → 1 分钟后 → 3 分钟后 → 9 分钟后 → ... 最长间隔 3 小时
- **状态持久化**：下载状态保存在 `UserDefaults` 中，App 重启后不会从头开始

自动下载的意义在于：**即使用户选的是云端转写方案，本地模型也在后台悄悄准备好，随时可以作为备用方案。**

---

## 11. 端到端转写流程

把上面所有组件串起来，一次本地语音转写的完整流程如下：

### WhisperKit 路径（进程内）

```
[用户操作] 按住快捷键
    │
    ▼
[录音] AudioRecorder 通过 AVFoundation 采集麦克风音频
    │
    ▼
[预热] prepareForRecording() → 提前加载 WhisperKit pipeline 到内存
    │      （等用户说话的这段时间不要浪费）
    ▼
[用户操作] 松开快捷键
    │
    ▼
[路由] LocalModelTranscriber 读取设置，确认使用 whisperLocal / whisperLocalLarge
    │
    ▼
[查找模型] preparedModelInfo() → 先查内置，再查 prepared.json，都没有则触发下载
    │
    ▼
[转写] WhisperKitTranscriber.transcribe(音频路径)
    │   ├── 内部调用 WhisperKit 库的 pipeline.transcribe()
    │   ├── CoreML 在 Neural Engine 上执行推理
    │   └── 进度回调 → 可以实时显示部分转写结果
    │
    ▼
[输出] 拿到完整转写文字
    │
    ▼
[后续] 可选 LLM 润色 → TextInjector 注入文字到前台 App
```

### Sherpa-ONNX 路径（进程外）

```
[用户操作] 按住快捷键
    │
    ▼
[录音] AudioRecorder 采集麦克风音频
    │
    ▼
[用户操作] 松开快捷键
    │
    ▼
[路由] LocalModelTranscriber 读取设置，确认使用 senseVoiceSmall / qwen3ASR / funASR
    │
    ▼
[查找模型] preparedModelInfo() → 检查模型和运行时是否就绪
    │
    ▼
[转码] AudioFileTranscoder 把音频转成 16-bit PCM WAV 格式
    │
    ▼
[转写] SherpaOnnxCommandLineDecoder
    │   ├── 构造命令行参数（模型路径、语言、token 数限制等）
    │   ├── 启动子进程：sherpa-onnx-offline <参数> <音频文件>
    │   ├── 设置 DYLD_LIBRARY_PATH 指向运行时的 lib/ 目录
    │   └── 读取子进程 stdout 输出（纯文字或 JSON）
    │
    ▼
[输出] 拿到转写文字
    │
    ▼
[后续] 可选 LLM 润色 → TextInjector 注入文字到前台 App
```

---

## 12. 多级降级策略

Typeflux 不会因为某一个转写方案失败就彻底罢工。`STTRouter` 实现了一条多级降级链：

```
主转写方案（用户选择的云端/本地方案）
    │ 失败
    ▼
自动本地模型（AutoModelDownloadService 下载的 SenseVoice）
    │ 失败
    ▼
Apple Speech 框架（macOS 系统自带的语音识别）
    │ 失败
    ▼
报错
```

具体规则：

- **如果用户选的是 Typeflux Official 云端方案**：先跑本地自动模型（节省云端额度），本地失败再走云端，云端也失败则降级到 Apple Speech。
- **如果用户选的是其他云端方案**：云端失败后，先试本地自动模型，再降级到 Apple Speech。
- **如果用户选的就是本地方案**：本地失败后，直接降级到 Apple Speech。

这意味着：**即使你在坐飞机没有网络，Typeflux 依然可以工作。**

---

## 13. 五个模型怎么选

| 模型 | 大小 | 中文质量 | 英文质量 | 速度 | 适用场景 |
|------|------|---------|---------|------|---------|
| **SenseVoice Small** (默认) | 47MB | ★★★★ | ★★★ | 快 | 日常中文语音输入，性价比最高 |
| **Qwen3-ASR** | ~300MB | ★★★★ | ★★★★ | 中等 | 中英混合场景较多 |
| **FunASR / Paraformer** | ~80MB | ★★★ | ★★ | 快 | 纯中文场景，资源紧张时 |
| **WhisperKit Medium** | ~1.5GB | ★★★★ | ★★★★★ | 较慢 | 对英文质量要求高，内存充足 |
| **WhisperKit Large-v3** | ~3GB | ★★★★ | ★★★★★ | 慢 | 追求最高精度，不在意资源消耗 |

**选择建议**：如果你不确定选什么，**保持默认的 SenseVoice Small 就好**。它小、快、中文效果好，是 Typeflux 按住说话松开插入这种快速交互场景下的最优解。

---

## 14. 关键设计决策回顾

1. **两套运行时并存**：WhisperKit（进程内、流式、高质量但重）和 Sherpa-ONNX（进程外、批量、轻量但无进度反馈）。不同场景用不同方案，而不是一刀切。

2. **运行时与模型解耦**：运行时和模型独立下载、独立存储、独立版本管理。这使得升级模型不需要重新安装运行时，反之亦然。

3. **双下载源 + 延迟探测**：HuggingFace 和中国镜像并存，实时探测速度选择最优源，确保国内外用户都有好的体验。

4. **激进的降级链**：主方案 → 本地自动方案 → Apple Speech。任何一层失败都不会让 App 罢工。

5. **Lazy + Eager 加载策略**：WhisperKit 在用户还在说话时就开始预热（eager），Sherpa 模型因为是进程外调用无需预热。资源消耗和响应速度之间取得了平衡。

6. **内置 + 按需下载**：Full 变体开箱即用，Minimal 变体首次使用时自动下载。通过符号链接统一路径，代码无需感知差异。

---

## 15. 相关文档

- [LOCAL_ASR_BENCHMARK.md](./LOCAL_ASR_BENCHMARK.md) — 本地 ASR 模型基准测试
- [BUILD_CONFIGURATION.md](./BUILD_CONFIGURATION.md) — 构建与签名配置（包含内置模型构建变体）
- [MAKE_COMMANDS.md](./MAKE_COMMANDS.md) — Makefile 命令参考
