# 核心流程与时序

## 名词
- `instructionText`：语音指令/口述内容经 STT 转写后的文本
- `finalText`：最终要注入/替换/复制的文本

## 普通输入模式（插入光标）
前置：未选中文本，或无法获取选区文本。

1. Fn 按下 -> `HotkeyService.onPressBegan`
2. `AudioRecorder.start()`
3. `Overlay.show(status: recording)` + 波形/计时更新
4. Fn 松开 -> `HotkeyService.onPressEnded`
5. `AudioRecorder.stop() -> AudioFile`
6. `Overlay.update(status: processing)`
7. `STTRouter.transcribe(audioFile) -> instructionText`
8. `TextInjector.insert(instructionText)`
   - 若失败：降级（见“注入失败降级”）
9. `Clipboard.write(instructionText)`（无论注入成功与否均执行）
10. `HistoryStore.append(audioFile, instructionText, mode=dictation)`
11. `Overlay.dismiss()` 或短暂显示成功状态后消失

## 文本编辑模式（替换选区）
前置：Fn 按下时能获取到 `selectedText`（非空）。

1-7 同普通模式，得到 `instructionText`
8. `LLMService.streamEdit(selectedText, instructionText) -> stream(finalTextDelta)`
9. UI（可选）：Overlay 在 processing 状态下可逐步展示部分 `finalText`（不强制）
10. 拼接得到 `finalText`
11. `TextInjector.replaceSelection(finalText)`
   - 若失败：降级（见“注入失败降级”）
12. `Clipboard.write(finalText)`
13. `HistoryStore.append(audioFile, finalText, mode=edit)`
14. `Overlay.dismiss()`

## 注入失败降级（强约束）
- 任何注入/替换失败：
  - 必须保证 `Clipboard.write(text)` 已执行
  - Overlay 明确提示：已复制到剪贴板（必要时提示开启辅助功能权限）

## 失败场景
- 麦克风无权限/设备不可用：失败态 + 引导授权
- STT 失败：失败态 + 视情况复制可用内容到剪贴板
- LLM 失败（编辑模式）：重试最多 3 次，仍失败则失败态 + 剪贴板保障
