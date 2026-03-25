# 模块划分与职责边界

> 本文定义模块职责、输入输出与核心接口契约。实现上可先放在一个 target 内按目录拆分；后续可演进为 SwiftPM 多模块。

## Modules/Hotkey
- 目标：全局快捷键按住/松开监听；默认 Fn；支持用户配置其他快捷键集合；配置变更立即生效。
- 核心接口：
  - `HotkeyService`
    - `start()` / `stop()`
    - `updateBindings(...)`（配置即时生效）
    - 回调：`onPressBegan`、`onPressEnded`

## Modules/Audio
- 目标：录音开始/停止、提供音量采样（波形）、输出音频文件供 STT/历史保存。
- 核心接口：
  - `AudioRecorder`
    - `start()`（开始录音并持续输出 level）
    - `stop() -> AudioFile`（返回文件路径/时长等）

## Modules/Overlay
- 目标：录音浮层固定显示在屏幕正中央下方；展示状态文本、波形、计时。
- 核心组件：
  - `OverlayWindowController`（AppKit Window/Panel）
  - `OverlayViewModel`（状态、计时、波形）

## Modules/STT
- 目标：音频转文字。
- Provider：
  - `WhisperProvider`：OpenAI-compatible `/audio/transcriptions`
  - `AppleSpeechProvider`：`SFSpeechRecognizer`
  - `CustomProvider`：用户配置的自定义 STT（若提供）
- 路由：`STTRouter` 根据配置选择 Provider。
- 核心接口：
  - `Transcriber`
    - `transcribe(audioFile) async -> String`

## Modules/LLM
- 目标：编辑模式下把 `selectedText + instructionText` 生成 `finalText`；支持 Streaming；失败重试。
- 核心接口：
  - `LLMService`
    - `streamEdit(selectedText: String, instruction: String) -> AsyncThrowingStream<String>`
- 约束：LLM 输出为“纯替换后的文本”，不包含解释性文本。

## Modules/TextInjection
- 目标：
  - 获取选区文本（用于判断是否进入编辑模式）
  - 插入文本到当前光标
  - 替换当前选区
- 实现策略：
  - 首选 `AXTextInjector`（Accessibility API）
  - 失败时降级：`PasteFallbackInjector`（仅写剪贴板并提示用户手动粘贴）
- 核心接口：
  - `TextInjector`
    - `getSelectedText() -> String?`
    - `insert(text: String) throws`
    - `replaceSelection(text: String) throws`

## Modules/Clipboard
- 目标：统一写入系统剪贴板。
- 核心接口：
  - `ClipboardService.write(text: String)`

## Modules/History
- 目标：保存近一周历史记录；每条包含音频文件与最终文本；支持播放/导出 Markdown/清空。
- 存储建议：音频文件存文件夹；元数据 JSON 索引。
- 核心接口：
  - `HistoryStore`
    - `append(record)`
    - `list()`
    - `purge(olderThanDays: 7)`
    - `exportMarkdown(...)`
    - `clear()`

## Modules/Settings
- 目标：提供设置 UI 与配置存储。
- 分层：
  - Presentation：`SettingsWindowController`、`SettingsView`
  - Application：`SettingsViewModel`
  - Infrastructure：`SettingsStore`、`OllamaLocalModelManager`
- 配置项：
  - 快捷键集合（含 Fn 与其他组合键）
  - LLM：BaseURL、API Key、Model
  - STT：Whisper endpoint/key/model、Apple Speech 开关、自定义 provider（若有）
- 存储：
  - 非敏感（BaseURL/Model/开关）放 UserDefaults
  - API Key 建议放 Keychain
- 约束：
  - View 只负责渲染和事件绑定，不直接读写 `UserDefaults`
  - ViewModel 负责状态同步、配置写入和本地模型准备等用例编排
