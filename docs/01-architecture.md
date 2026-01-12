# 总体架构设计

## 技术栈
- 语言：Swift
- UI：SwiftUI（设置/历史/部分状态）+ AppKit（菜单栏 `NSStatusItem`、Overlay `NSPanel`）
- 音频采集：AVFoundation（`AVAudioEngine` / `AVAudioRecorder`）
- STT：
  - OpenAI-compatible Transcriptions（Whisper 类服务）
  - Apple Speech（`SFSpeechRecognizer`）
  - 预留自定义 STT Provider（若配置提供）
- LLM：OpenAI-compatible ChatCompletions（Streaming）
- 文本注入：Accessibility API（AX）优先；降级剪贴板
- 存储：文件系统（音频文件）+ JSON 索引（历史记录元数据）

## 分层（建议）
- Presentation：菜单栏、设置页、历史页、录音浮层
- Application：用例编排（按住录音、松开处理、注入/替换、落库）与状态机
- Domain：协议与模型（对外稳定接口）
- Infrastructure：OS API、网络、文件系统实现

## 应用主状态机
- `idle`：就绪
- `recording`：录音中（浮层显示波形与计时）
- `processing`：处理中（转写/生成/注入）
- `failed`：失败态（明确提示；确保至少剪贴板可用）

## 权限与降级策略
- 麦克风权限：未授权则进入 `failed`，提示去系统设置授权。
- 辅助功能（Accessibility）：
  - 未授权：无法自动注入/替换，降级为“写剪贴板 + UI 提示手动粘贴”。
- 部分应用/控件无法注入：同上降级。

## 依赖注入与可替换性
核心依赖统一通过容器组装：
- `HotkeyService`
- `AudioRecorder`
- `Transcriber`（由 `STTRouter` 按配置/可用性选择具体 Provider）
- `LLMService`
- `TextInjector`
- `ClipboardService`
- `HistoryStore`

目的：
- 可替换 STT/注入实现
- 便于单元测试（Mock 依赖）

## 重试策略
- LLM 调用失败：自动重试最多 3 次（含首次失败后的重试次数累计上限）。
- STT 调用失败：
  - 若配置允许，尝试切换到备选 Provider（例如从 Whisper 切到 Apple Speech）
  - 否则进入失败态，并至少把“已获取到的文本/错误信息”写入剪贴板（若合理）
