# Task02 终曲 V6.2 命中诊断 v0.1.1

**仅诊断，不是 Bolt 修复版终曲。未经过游戏 2.5 的实际 REDscript 编译或实机测试。**

此版本作为整个 Task02 诊断 v0.1.0 的替换包，保留原攻击选择与两类弹丸观察，新增 V6.2 命中字段：`WeaponCharge`、`PerfectlyCharged`、`NativeBoltFlag`、`BlackwallFullCharge`，另有 `IsRanged`。

- `PerfectlyCharged` 直接读取 `hit.attackData.HasFlag(hitFlag.PerfectlyCharged)`；该接口/枚举已在有 2.5 版本来源的社区 NativeDB RTTI 中核实，但标志是否对应所有 Bolt、到该阶段是否保留仍需实机确认。
- `NativeBoltFlag` 明确为 `UNAVAILABLE`，不是 false，也不是将 PerfectlyCharged 改名为 Bolt。
- `BlackwallFullCharge = IsRanged && (WeaponCharge >= 0.999 || PerfectlyCharged)`，仅复现正式 V6.2 条件用于日志，没有触发或重放黑墙。
- 旧 `full_charge_by_finale_threshold` 字段保留，仅代表数值是否达到 0.999，不能拿它代替 V6.2 完整判定。
- 未修改正式终曲的任何文件、黑墙参数、Boss 7秒加速、武器属性、四槽、语音、V4 文本、材质/App修复，未加入 TMC。

## 安装与回退

1. 完全退出游戏，归档此前日志，备份测试存档。
2. 保持正式终曲 V6.2 一体化包和原 CHRONOS V0.3.2 启用。确认 CHRONOS 两个被覆盖的脚本与先前 Task02 基线一致；如果你的成功版本含额外飞刀代码，先按 Diff 合并，不能盲目覆盖。
3. 在 Vortex 禁用旧 Task02 v0.1.0 诊断补丁，再安装 `CHRONOS_TASK02_FinaleHitDiagnostics_V0.1.1.zip`。新补丁须赢得与 CHRONOS 的两个同路径脚本冲突；不要把 v0.1.0/v0.1.1 以重复脚本副本同时部署。
4. 启动后先检查 `<游戏根目录>/r6/logs/redscript_rCURRENT.log`。编译失败立即停止测试并回退，不能用 CET 窗口能打开代替编译检查。
5. 打开 CET，确认新增日志 `session_begin` 的 `version` 为 `0.1.1`，再开始测试。
6. 回退：退出游戏，在 Vortex 禁用新补丁，重新启用旧诊断或仅保留原 CHRONOS，再部署。检查同名文件恢复。手动安装时，必须同时恢复两个 CHRONOS 脚本并移除新增诊断目录；不能只删诊断类而保留对它们的调用。优先使用测试前存档。

此 ZIP 是完整诊断替换包，不包含完整 CHRONOS/终曲，不应独立替代原 MOD。

## 单发测试流程

CET 模块仍名为 `CH13FinaleDiagnostics`，面板/热键和控制台 API 不变：

```lua
GetMod('CH13FinaleDiagnostics').arm('Normal')
-- 只打一发普通射击，等待命中后：
GetMod('CH13FinaleDiagnostics').stop('normal_done')
```

每组单独 Arm、只射击一发、Stop。可使用面板和 CET 热键，避免控制台影响操作。窗口最多 12 秒，手动标签不是自动识别的射击模式。建议采集四组：

1. 普通射击：Normal 标签。
2. 非 Bolt 的部分蓄力：Normal 标签，并在射击前用 `mark('partial_non_bolt')` 备注。
3. 满蓄力且非 Bolt：Charged 标签，以游戏表现确认不是 Bolt。
4. 游戏表现明确确认的 Bolt：Bolt 标签，并保留 Bolt 提示/操作录像。

```lua
GetMod('CH13FinaleDiagnostics').arm('Normal')
GetMod('CH13FinaleDiagnostics').mark('partial_non_bolt')
-- 完成一发测试，再 stop。mark 仅人工备注，不是引擎开火事件。
```

先在克洛诺斯关闭、无遮挡、单一存活目标上测试。每组的首次标记测试优先换未标记目标；再针对已有上传测试后续进度。记录技能、插件与目标类型。Boss 加速在其已有上传上单独复测。随后再按需求开启克洛诺斯测试；不要改变已有六秒及生命消耗设定。

`BlackwallFullCharge` 为 true 但标记未出现时，应核对 `can_execute`、before/after 的上传/标记状态及异步应用情况，不能立即判定为 Bolt 分类错误。已有进度不会因为另一次命中重新开始。普通/部分蓄力应保留原有后续普通命中的进度加成，不能把“不能启动蓄力黑墙”误解为“完全不影响已有上传”。

## 日志与输出

```text
<游戏根目录>/bin/x64/plugins/cyber_engine_tweaks/mods/CH13FinaleDiagnostics/finale_diag.jsonl
```

仍为追加写入的 JSONL，CET 控制台同时输出 `[CH13FD]` 前缀。文件写入失败时从控制台复制。每组以 `session + trial` 区分；只提交某条 selection 或给手动标签不能证明是 Bolt。

请提供整个会话的日志与对应录像/操作说明，并确认 `trial_end` 的 `dropped=0`、`selection_transitions_suppressed=0`、`drain_error=false`，无 `telemetry_error`。`sim_time` 是引擎模拟时间，`poll_real_seconds` 是 CET 收集时间，不能直接当作精确发射/伤害结算时刻。

两类弹丸初始化之外的实体仍未覆盖；未观察到实体不等于 Hitscan。该版本没有新增通用开火、原生 Bolt 状态、全局伤害或附加攻击链挂钩。

源码和对 v0.1.0 的 Diff 包含在审查 ZIP 中。四项分类模拟测试及原有生命周期测试通过，但不是游戏内编译或 Bolt 成功触发的证据。详细调查、来源与限制见配套 `BOLT_INVESTIGATION_zh.md`。
