# 配置设计

## 配置项（建议）

### Hotkey
- `useFnAsPrimary: Bool`：默认 true
- `customHotkeys: [HotkeyBinding]`：用户自定义组合键集合
- 立即生效：设置页写入后触发 `HotkeyService.updateBindings(...)`

### STT
- `stt.provider: enum`：auto / whisper / appleSpeech / custom
- Whisper（OpenAI-compatible transcriptions）
  - `stt.whisper.baseURL`
  - `stt.whisper.apiKey`
  - `stt.whisper.model`
- Apple Speech
  - `stt.appleSpeech.enabled`
- Custom
  - `stt.custom.baseURL`
  - `stt.custom.apiKey`（若需要）
  - `stt.custom.protocol: enum`（建议支持 `openai_transcriptions` 或 `custom`）

### LLM（OpenAI-compatible ChatCompletions）
- `llm.baseURL`
- `llm.apiKey`
- `llm.model`
- `llm.temperature`（可选）

## Provider 路由策略（建议实现为 STTRouter）
- 当 `stt.provider == custom` 且 custom 配置完整：使用 Custom
- 当 `stt.provider == whisper` 或 `auto` 且 whisper 配置完整：使用 Whisper
- 否则：使用 Apple Speech（作为本地/系统备选）

> 该策略覆盖了“默认 Whisper，同时支持 Apple Speech；若用户配置了自定义 provider 则优先使用自定义”的需求。

## 存储建议
- UserDefaults：
  - baseURL、model、开关、快捷键列表
- Keychain：
  - STT/LLM API Key（避免明文落盘）

## 变更通知
- `SettingsStore` 在配置变化时发送通知（例如 Combine Publisher 或 NotificationCenter）
- 订阅方：
  - `HotkeyService`（立即更新绑定）
  - `STTRouter`（更新 Provider）
  - `LLMService`（更新 baseURL/model）
