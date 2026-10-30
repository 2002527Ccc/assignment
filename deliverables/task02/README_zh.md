# CHRONOS 开发任务 02：终曲运行时诊断补丁 v0.1.0

本包是诊断工具，不是技术弹丸冻结实现。**未在《赛博朋克2077》2.5 中编译或运行。首次安装必须先检查 redscript 日志；Lua 宿主模拟和文本审计不等于游戏验证。**

## 适用基线与交付文件

- 基线：本次提供的 CHRONOS V0.3.2 ZIP，以及终曲 ZIP 中的 `OneEyedTech.reds`。源文件哈希见 `SHA256_MANIFEST.json`。
- 依赖：两份原 MOD 及它们原有依赖、CET。没有新增外观资源、TweakXL YAML、游戏数值或第三方库。
- `CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip`：Vortex 安装包，仅两个 CHRONOS 文件覆盖、两个新增诊断 REDscript 文件和一个独立 CET 目录。
- `CHRONOS_TASK02_Source_and_Review.zip`：源码、构建工具、验证工具、说明、完整 diff、哈希清单和验证报告。不是 Vortex 安装包。
- `CHRONOS_V032_to_TASK02.diff`：相对原 V0.3.2 的完整补丁；未改变的原文件不重复分发。

如果你实际成功运行的版本与附件基线不同，尤其包含额外飞刀逻辑，**不要用本包覆盖不同版本的同名文件**。应先按 diff 审查、合并其中的诊断插入段。本包没有飞刀代码，不能验证外部飞刀实现的兼容性。

源码包的 `install_tree/` 包含所有完整安装文件，`source/` 保存三个新增诊断源文件。重新构建时先解压原始 CHRONOS 和终曲 ZIP，再运行 `python3 build.py --chronos-base <CHRONOS解压目录> --finale-base <终曲解压目录>`。结构审计使用 `python3 verify.py` 的同名路径参数；Lua 模拟测试为 `python3 test_lua.py`，需要系统有 `liblua5.4`。这些验证不安装游戏依赖，也不是游戏编译器。

## 修改范围与行为边界

1. 在现有 `WeaponTransition.GetDesiredAttackRecord` 包装中，原始 `wrappedMethod()` 返回后、Power/克洛诺斯激活条件过滤前，加入只读记录调用。原有包装仍然只有一个；原有 `wrappedMethod()` 调用次数、返回表达式、转换映射和条件全部保留。
2. 在现有 `sampleBullet` / `sampleBulletGeneric` 初始化包装尾部加入记录调用；不增加初始化包装，不修改 OnTick、速度设置、轨迹或寿命管理。
3. 新增对 `OneEyedTech.OET_UploadHitEffector.RepeatedAction(owner: ref<GameObject>) -> Void` 的包装。签名直接取自附件源码，`wrappedMethod(owner)` 正好执行一次；只在其前后读取命中上下文和黑墙状态。
4. 新增玩家诊断字段和最多 128 条的内存队列。CET 每 0.1 秒读取；未启用测试时不记录。相同攻击/攻击包的连续选择回调去重，每个测试最多记录 32 次选择转换。丢弃/抑制数量写入测试结束日志。
5. CET 模块使用独立目录，不改 CHRONOS 原有 CET init.lua/config.lua。不设置 TweakDB、时间、伤害、状态效果、武器属性，不生成弹丸，不补发命中。

日志读取/磁盘写入在 CET 更新阶段执行，不在原始攻击调用里执行 I/O。但任何未编译的新脚本仍存在兼容性风险，不能仅凭静态检查保证实机零影响。

## 数据覆盖与明确限制

| 数据 | 记录方式 / 限制 |
|---|---|
| 物品记录 | 选择/命中读取实际 `GetItemID()`，仅接受 `Items.Finale` |
| 实际选择记录 | 记录 `wrappedMethod()` 实际返回对象的 ID；不拿 DefaultFire 替代它 |
| 攻击包 | 记录当时 `m_rangedAttackPackage` ID、DefaultFire ID，并只读探测若干候选 flat |
| 记录类型 | 保留 CET 的 RTTI 对象原始文本；没有核实的类名 API，不调用它。`runtime_type=UNAVAILABLE` |
| 当前模式 / Bolt | 不能可靠读取原生状态；Normal/Charged/Bolt 均是手动标签，不是识别结果 |
| 发射事件 / 发射蓄力 | 没有确认签名的通用发射事件挂钩；明确 `UNAVAILABLE`。选择记录不算发射事件 |
| 命中蓄力 | 在终曲原有命中后效器读取该次 `attackData.GetWeaponCharge()`；不当作精确发射回调时间的采样 |
| 实体弹丸 | 只观察现有两类初始化回调；存在回调是正面实体证据，无回调不能证明 Hitscan |
| 实体归属 | 初始化事件的 owner 必须为玩家；另检查当时主动武器为终曲。但这不能严格证明该实体来自本次终曲射击 |
| 实际实体类 / 模板 / 轨迹类型 | 标为 `UNAVAILABLE`；hookClass 仅是挂钩类，不宣称为实际派生类。速度字段不证明轨迹一定线性 |
| 命中与黑墙阶段 | 记录 `OET_UploadHitEffector.RepeatedAction` 前后、目标 ID、蓄力、是否可执行、上传对象/进度、两种标记状态 |
| 通用命中 / 最终伤害 | 未挂全局伤害管线，未直接测量最终伤害结算；空枪、墙体命中、其他附加攻击可能不进入该后效器 |
| 额外攻击 / Bolt 效果链 | 记录不同选择记录及可读取的 effect/status flat，作为线索；不保证覆盖原生技能及插件产生的独立攻击 |

候选 flat 名只通过已知的 `TweakDB:GetFlat` 接口探测。缺失、读取失败统一记 `UNAVAILABLE`，不能据此断言属性不存在。TweakDBID 日志保留 CET 原始字符串；如果不能反解出名称，哈希形式的 ID 仍可用于比较，不编造人类可读名称。

黑墙前后状态比较反映该后效器调用边界，`after` 不等于“所有异步状态效果都已应用”。已有黑墙上传可能是在先前射击中产生，不能把每次观察到上传对象都当作新触发。此模块没有自动识别黑墙最终处决或义体故障的全部事件。

每条 REDscript 事件保存 `sim_time`。CET 的 `poll_real_seconds` 是收集时刻，允许至多一个轮询周期及帧调度延迟；不是引擎回调精确墙钟时间。克洛诺斯减速时两种时间尺度不同，不能用它们直接计算弹速或证明“同帧结算”。

## 安装（Vortex）

1. 完全退出游戏，备份存档；保留原 CHRONOS V0.3.2 和终曲安装包。
2. 对照清单确认现有 `CH13HitscanConversion.reds`、`CH13Projectiles.reds` 与附件基线一致。存在其他改动时先合并 diff，不盲目覆盖。
3. 保持原 CHRONOS 与终曲启用，安装 `CHRONOS_TASK02_FinaleDiagnostics_V0.1.0.zip`，类型按原 CHRONOS 的 Cyberpunk 游戏目录安装方式处理；使 `r6`、`bin` 落在游戏根目录。
4. 设置本补丁 **在 CHRONOS V0.3.2 之后部署/赢得文件冲突**，仅覆盖上述两个同路径脚本；不要禁用原 CHRONOS，补丁不包含其完整核心。
5. 部署后检查无重复 `.reds` 副本。不要同时启用其他版本的 Task02 补丁。测试期间停用其他攻击选择/弹道/黑墙后效器修改 MOD，排除包装链干扰。
6. 启动游戏，先查看 `<游戏根目录>/r6/logs/redscript_rCURRENT.log`。如果编译失败，停止测试，执行卸载回退并提交完整错误。CET 界面显示 Loaded/Ready 不能证明 REDscript 编译成功，必须实际 Arm 成功。

## 三次射击的测试流程

建议先在克洛诺斯关闭时采集一组，再开启时采集一组，以区分原生行为与时间缩放影响。优先使用备用存档、终曲、单一存活目标和无遮挡场地；先移除会改变攻击效果的插件，记录插件清单后再按需补测。正常与蓄力对照时可用未学习 Bolt 的测试存档；已有 Bolt 时，避免把处于 Bolt 窗口的释放误标为普通满蓄力。

1. 打开 CET 的此诊断窗口，或者在 CET 热键设置中为 `CH13FD: arm Normal/Charged/Bolt`、Stop 和可选 Manual trigger reference 绑定不冲突的按键。模块不预设键位。
2. 装备终曲并瞄准单一目标。点击 **Arm Normal**，关闭 overlay，正常射击 **一发**。等待命中，按 Stop；也可等 12 秒自动停止。
3. 使用另一个未标记的存活目标，Arm Charged，进行一次你确认的满蓄力非 Bolt 射击，然后 Stop。不要依赖日志中的手动标签反过来证明它不是 Bolt。
4. 使用另一个未标记的目标，Arm Bolt，在游戏的 Bolt 提示/技能条件下完成一次你确认的 Bolt，再 Stop。记录是否出现 Bolt 提示，最好附屏幕录像；标签不代表代码识别了 Bolt。
5. 每次 Arm 都得到递增 `trial`，每条日志带 `session`、`trial`、`manual_label`、`seq`。三个测试窗口各只打一发，才能把日志人工归到这三发；**此模块没有自动的逐发 shot ID**。一次窗口误打多发则重做，不把其中多次选择回调当作多次发射。
6. 若要比较实际扳机时刻，可按 Manual trigger reference 热键或用下述 `mark()`。它仅是人工参考，不是原生开火回调。请用录像核对扳机、枪口、目标血量和黑墙 UI 时间。
7. 检查每次 `trial_end`：`dropped=0`、`selection_transitions_suppressed=0`、`drain_error=false`，并且没有 `telemetry_error`。任何异常意味着日志不完整；缺事件不能做否定性推断。
8. 核对选择事件、弹丸初始化、黑墙 before/after 顺序；`hit_weapon_charge` 是命中上下文中的蓄力值。攻击选择与命中间没有经过验证的一一映射，只能在单发窗口结合目标 ID 人工对应。穿墙、群体效果或附加链可能产生多次命中回调。
9. 再对远距离、遮挡穿墙各做独立测试。开启克洛诺斯的测试不要改变其 6 秒/生命消耗设定；沿用你原有安全测试存档与方式。
10. 回归测试：用原有动能武器和飞刀验证原先的冻结/释放，用终曲核对普通、蓄力、Bolt、穿墙、黑墙、义体故障、四槽及外观/语音没有变化。没有做这些实机测试前，不宣称完全兼容。

可选 CET 控制台命令（先加载存档）：

```lua
GetMod('CH13FinaleDiagnostics').arm('Normal')
GetMod('CH13FinaleDiagnostics').arm('Charged')
GetMod('CH13FinaleDiagnostics').arm('Bolt')
GetMod('CH13FinaleDiagnostics').mark('trigger_reference')
GetMod('CH13FinaleDiagnostics').stop('manual_console')
```

不要在一次测试中依次执行三条 arm；每条 arm 对应一次独立测试。

## 日志保存与读取

主要文件：

`<游戏根目录>/bin/x64/plugins/cyber_engine_tweaks/mods/CH13FinaleDiagnostics/finale_diag.jsonl`

这是 CET 模组沙箱内的相对路径文件，每条记录一行 JSON，追加写入。若此 CET 版本禁止文件写入，窗口会显示写入失败；相同内容仍通过 `print` 输出，以 `[CH13FD]` 开头，可直接从 CET 控制台复制。也可在 CET 的日志目录中搜索这个前缀；不同 CET 版本的 print 汇集文件名可能不同，不将某个文件名当作唯一落点。

每次进入游戏有独立 `session`；trial 从该次 CET 会话的 1 开始。归档时按 **session + trial** 分组，不只看 trial。REDscript queue 是内存暂存，不是磁盘日志；Stop 会立即尝试排空，关闭游戏前先 Stop。游戏崩溃前尚未收集的队列可能丢失。

请提供：完整 `finale_diag.jsonl`、redscript 编译错误（如果有）、游戏/CET/redscript/依赖版本、三种模式的实际操作与 Bolt 画面证据、技能与插件配置、是否开启克洛诺斯。不要只截取一条 `selection` 当作整次射击结论。

## 卸载与回退

1. Stop，完全退出游戏，先复制保存 JSONL（Vortex 清理文件时可能一并移除目录）。
2. Vortex 禁用/卸载 **本 Task02 补丁**并重新部署，保留原 CHRONOS V0.3.2 和终曲。确认原 CHRONOS 重新赢得两个脚本文件。
3. 确认 `r6/scripts/CH13FinaleDiagnostics/` 两个新增 `.reds`、独立 CET 目录及其手动残留副本已移除；不删除终曲目录或原 CHRONOS 目录。
4. 若手动安装：用原包恢复 `r6/scripts/Chronos13/CH13HitscanConversion.reds`、`CH13Projectiles.reds`，移除上述诊断目录。不能只删除新增诊断文件，否则覆盖文件仍引用 CH13FD，导致编译失败。
5. 核对基线 SHA256，再启动并检查 redscript 日志。无需修改游戏存档内的武器；诊断没有主动写入物品/数值，但新增脚本字段的序列化和卸载行为未经实机验证，优先恢复测试前备份存档。

## 签名、加载与兼容性检查范围

- `GetDesiredAttackRecord(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> ref<Attack_Record>`、两个 `OnProjectileInitialize(eventData: ref<gameprojectileSetUpEvent>) -> Bool`：保持附件已有方法和签名，没有新增同方法包装。
- 新包装 `OET_UploadHitEffector.RepeatedAction(owner: ref<GameObject>) -> Void`：与附件定义逐项一致；模块导入 `OneEyedTech.*`，无同名重复类。此自定义类必须存在，因此本补丁不能脱离终曲单独使用。
- REDscript 按符号解析依赖，不用文件名字母排序宣称包装链顺序；与未知 MOD 的其他包装先后不能在此环境保证。Vortex “之后”只解决文件覆盖顺序，不决定 REDscript 包装链顺序。
- 新调用 API 仅复用附件已使用的游戏接口、REDscript 标准数组/类型功能，以及 CET 的常规 JSONL 文件/日志、生命周期、热键、TweakDB 只读访问。没有添加未经核实签名的原生开火、Bolt、全局伤害或反射方法。
- 当前没有游戏 2.5、完整脚本缓存、REDscript 编译器、CET 宿主或 WolvenKit。静态检查无法核实自定义方法的游戏内导出、CET/REDscript interop、编译器版本特性或未知 MOD 包装链。以首次实机编译和日志为准。
