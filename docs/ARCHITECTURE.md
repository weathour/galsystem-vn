# galsystem 架构骨架

目标：用于《白色相簿》/《命运石之门》类型长篇 ADV/Galgame。

## Phase 1 决策

Phase 1 完成的是 **ADV Core Vertical Slice**。当前已进入 Phase 2：Dialogue Manager v3.10.4 已作为第二后端接入，`.galscript` 保留为可回退路径；当前 `scenario/dialogue_manager/chapter_01.dialogue` 已作为 DM 短章节入口；下一步是继续迁移更多真实章节，同时保持存读档、手机、日程、路线和 flow 追踪可验证。

## 分层

- `autoload/VNState.gd`：唯一剧情状态源。flags、variables、affection、route、chapter、day、worldline、backlog、CG/TIPS 解锁都在这里。
- `autoload/ScenarioRunner.gd`：最小文本剧本运行器。支持当前行/选项 checkpoint、label/choice flow 追踪、`if_flag`、`if_var`、`if_affection`、`if_calendar_event`；现在作为 fallback 后端。
- `scripts/systems/DialogueManagerAdapter.gd`：Dialogue Manager v3.10.4 适配层。把 `DialogueLine`/`DialogueResponse` 转为 `VNDirector` 可消费的字典，并通过 `do` mutation bridge 驱动同一套演出/系统命令。
- `scripts/presentation/VNDirector.gd`：运行壳层。包含标题流、打字机、auto/skip、backlog、系统菜单、存读档面板、debug 面板、flow 面板和命令派发。
- `autoload/SaveSystem.gd`：JSON 存档，含 `save_version`、`scenario_backend`、VNState、ScenarioRunner checkpoint 或 Dialogue Manager snapshot、演出快照、PhoneSystem、CalendarSystem、FlowchartSystem。
- `autoload/RouteManager.gd`：路线/结局判定。
- `scripts/systems/PhoneSystem.gd`：短信/电话触发器原型。支持 receive/read/reply 和 snapshot/restore。
- `scripts/systems/CalendarSystem.gd`：日程/事件调度原型。支持 day advance、flag + affection 条件事件和 snapshot/restore。
- `autoload/FlowchartSystem.gd`：轻量 flow/debug 追踪，记录 visited labels 和 choice history；不是完整路线图编辑器。

## Phase 1 已验证能力

- 标题/开始流程。
- 打字机文本显示；点击时先展开当前句，再推进。
- Auto mode / Skip mode。
- Backlog 面板。
- 系统菜单。
- 6 个存档槽 UI + F5/F9 快存快读。
- Debug 面板显示脚本 checkpoint、当前行、flags、variables、affection、phone/calendar 状态。
- Flow 面板显示当前 label、visited labels、choice history。
- 手机链：mail received -> read -> reply -> worldline/TIPS/CG -> branch observed。
- 日程链：advance day -> affection threshold -> scheduled event -> route lock。
- `.galscript` 静态 lint。
- Headless smoke 对两条分支做确定性断言。
- Dialogue Manager smoke 对手机分支、日程分支、命令桥接和选择肢前存/读档做确定性断言。

## 验证命令

```bash
python3 tools/lint_galscript.py scenario
godot --headless --path . --quit-after 3
godot --headless --path . --quit-after 120 -- --galsystem-smoke
```

预期 full smoke 输出：

```text
smoke: title flow visible
smoke: phone branch mail->read->reply->worldline/tips/cg ok
smoke: calendar/affection branch route lock ok
galsystem smoke ok
```

## 后续推荐顺序

1. 抽出命令注册表/命令执行层，减少 `ScenarioRunner`、`DialogueManagerAdapter`、`VNDirector`、lint 和文档之间的约定漂移。
2. 把当前代码生成 UI 逐步拆为 `DialogueBox.tscn`、`ChoiceMenu.tscn`、`SystemMenu.tscn`、`SaveLoadUI.tscn`。
3. 扩展 `PhoneUI.tscn`：短信收件箱、电话接听、关键词回复。
4. 实现更正式的 `FlowchartSystem` UI：章节跳转和路线图，但保持 Phase-2 范围。
5. 扩展 `EventScheduler`：日期、好感度、flag、路线状态共同触发事件。

## Phase 2 follow-ups

- Split `VNDirector.gd` into scene components (`TitleMenu`, `DialogueBox`, `ChoiceMenu`, `SaveLoadUI`, `DebugPanel`, `FlowPanel`).
- Extract scenario command contracts into a shared registry/adapter layer now that both `.galscript` and Dialogue Manager use the same VN shell.
- Move more branch/system command handling out of `ScenarioRunner.gd` when replacing it with a dialogue adapter.

## Dialogue Manager integration update

Dialogue Manager v3.10.4 is now installed under `addons/dialogue_manager/` and available as a second backend through `DialogueManagerAdapter.gd`. Its mutation bridge can now drive VN presentation/system commands from `.dialogue` files. See `docs/DIALOGUE_MANAGER_INTEGRATION.md`.

Additional validation:

```bash
godot --headless --editor --path . --quit-after 10
godot --headless --path . --quit-after 120 -- --galsystem-dm-smoke
```

Expected key output:

```text
dialogue manager smoke ok
```
