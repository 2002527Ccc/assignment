# 终曲 V6.2：原生 Bolt 与黑墙判定调查

结论：**目前只证实了 2.5 中相关命中接口和标志确实存在，尚未取得原版 Bolt 设置/传递这些标志的方法体，因此不修改正式终曲 MOD，也不宣称已经修复 Bolt。** 本次只增强用户允许的 Task02 诊断。

## 一、证据等级与来源

### A. 有版本来源的游戏 RTTI/API 证据

本次读取的社区 NativeDB 仓库为 `rayshader/cp2077-nativedb`，固定提交：

`8d418f04128ce43a4f70a47689895bb0e7ecda7b`

- [README：游戏 2.5 与 RTTIDumper 生成说明](https://github.com/rayshader/cp2077-nativedb/blob/8d418f04128ce43a4f70a47689895bb0e7ecda7b/README.md)
- [ngsw-config.json：appData.gameVersion = 2.5](https://github.com/rayshader/cp2077-nativedb/blob/8d418f04128ce43a4f70a47689895bb0e7ecda7b/ngsw-config.json)
- [数据更新提交：build: release v2.1.1, support patch 2.5 (#242)](https://github.com/rayshader/cp2077-nativedb/commit/766d8386d0f6d497f53cfc64f97b798d7d95cbcf)
- [classes.json 原始导出](https://github.com/rayshader/cp2077-nativedb/blob/8d418f04128ce43a4f70a47689895bb0e7ecda7b/src/assets/reddump/classes.json)
- [enums.json 原始导出](https://github.com/rayshader/cp2077-nativedb/blob/8d418f04128ce43a4f70a47689895bb0e7ecda7b/src/assets/reddump/enums.json)

这不是只从名字猜测版本：支持 2.5 的提交同时更新了 RTTI 资产。但它仍是社区发布的数据，不是本机运行游戏取得的验证。原始 JSON 为单行压缩格式，报告按对象名/键定位，未虚构逐函数源码行号；相关原始条目与 SHA256 摘录见 `NATIVE_API_EVIDENCE.json`。

`classes.json` 的对象 `b = gamedamageAttackData`、`c = AttackData` 包含：

```reds
HasFlag(flag: hitFlag) -> Bool
GetWeaponCharge() -> Float
GetFlags() -> array<SHitFlag>
GetTriggerMode() -> gamedataTriggerMode
GetAttackDefinition() -> ref<IAttack>
```

其中 `HasFlag;hitFlag` 是可调用的 public/final/const 脚本接口；它的存在不等于已经知道原版 Bolt 如何调用它。这里的“游戏原有接口”也不应混同于 REDscript 声明中的 `native` 实现标记。

`enums.json` 的 `hitFlag` 中确实包含：

```text
WeaponFullyCharged = 35
PerfectlyCharged   = 100027
ChainLightning    = 100028
```

枚举值仅作为源码对象定位证据；诊断使用符号名，不硬编码这些数字。

在此 RTTI 的 `hitFlag` 中未找到 `Bolt`/`BoltShot` 项，对导出类方法、全局函数和枚举名/成员的名称搜索也没有找到含 `Bolt` 的条目。**这只表示该份导出中没有找到这样的命名接口，不能证明引擎绝不存在任何内部 Bolt 状态或其他命名的判断方法。**

### B. 存在原版 PerfectCharge/PerfectDischarge 结构，但实现未取得

RTTI 还列出了：

- `PerfectDischargePrereq.IsDischargePerfect`：protected 方法，参数含 `game`、`weaponObject`、可选 `state`。原始 state 参数 flags `c=4` 对应 `opt`，不是 `out`。
- `WeaponObject.GetPerfectChargeWindow()`：private 方法。
- `WeaponObject` 的私有脚本字段 `perfectChargeStarted`、`perfectChargeReached`、`perfectChargeShot`。
- `PerfectDischargePrereqState.wasPerfectlyCharged`。

这些是继续查原版实现的具体入口，不是已经验证可直接写 `if (isBoltShot)` 的公开命中 API。没有方法体就不能确定该如何初始化 prereq/state，也不能推断它们与 Bolt 的完整对应关系。命中时重查当前武器充能状态还可能读到后续一次射击的状态，不能替代该次攻击快照。

因此本次不新增全局监听、不通过反射读取私有字段、不创建 prereq 对象重算 Bolt，也不硬编码 75%、65% 等新的充能阈值。

### C. 原版源码尚未证实的内容

尚未获得可引用的方法体来证明：

1. 哪段原版 Bolt/发射代码设置 `PerfectlyCharged`；
2. 所有 Bolt 是否都设置它，非 Bolt 是否也可能设置它；
3. 该标志是否一直保留到终曲的 `PostProcess / RepeatedAction`；
4. 技能、插件和附加攻击是否改变该传递路径。

已知原版反编译脚本源站 `codeberg.org/adamsmasher/cyberpunk` 经当前环境代理返回 CONNECT 403 Forbidden；`api.github.com` 访问也被拒绝；GitHub 网页代码搜索返回登录墙，不是“相关源码不存在”的证据。可访问的资料尚未补齐上述实现链。本次没有绕过网络策略。

为了继续源码调查，已将 `codeberg.org` 和 `api.github.com` 两个所需域保存到环境网络配置草稿，保留既有预设；**草稿保存不等于运行时已放行或配置已发布**。后续需在环境设置审阅、保存并发布相应配置，再重试受影响的读取。

## 二、V6.2 正式逻辑实际上已经做了什么

以本次上传的 V6.2 一体化包为准，其 `OneEyedTech.reds` 的 `OET_UploadHitEffector.RepeatedAction` 已经使用：

```reds
fullCharge = Equals(hit.attackData.GetAttackType(), gamedataAttackType.Ranged)
  && (hit.attackData.GetWeaponCharge() >= 0.999
      || hit.attackData.HasFlag(hitFlag.PerfectlyCharged));
```

该布尔值同时用于首次命中启动黑墙与已有上传的 `AddHitProgress(fullCharge)`。Boss 加速仍读取 `bossChargedSeconds = 7.0`；普通命中读取 `bossNormalSeconds = 1.0`，总上传时长 `359.0`。普通目标继续使用原有 7 秒、后续命中增加 19 点、低于 31% 生命处决的配置。

**静态推断**：若某次远程 Bolt 命中到达这个后效器时确实带有 `PerfectlyCharged`，V6.2 的现有代码应已走完整蓄力分支。重复加入同样的 OR 条件不会产生新的修复。若实机仍失败，应先确认标志、后效器调用、目标可执行条件、安装文件版本及上传状态，而不是扩大蓄力阈值。

本次没有改动正式终曲文件或任何伤害、上传参数、Boss 参数、四槽、语音、文本、材质、App 修复资源、TMC 依赖。原 V6.2 ZIP 和先前 Task02 交付均保留原字节。

## 三、本次唯一代码变更：命中诊断 v0.1.1

诊断仍仅在玩家的 `Items.Finale` 命中且已手动 Arm 时工作，在既有后效器执行前后记录：

| 字段 | 含义 |
|---|---|
| `WeaponCharge` | 该命中 attackData 的充能快照 |
| `PerfectlyCharged` | 该命中 `HasFlag(hitFlag.PerfectlyCharged)` 的真实读取值 |
| `NativeBoltFlag` | `UNAVAILABLE`；没有独立已证实的 Bolt 标志，不把未知写成 false |
| `BlackwallFullCharge` | 根据快照计算的 `IsRanged && (WeaponCharge >= 0.999 || PerfectlyCharged)` |
| `IsRanged` | 原版远程攻击类型比较结果，用于排除近战误判 |

`BlackwallFullCharge` 只是对正式 V6.2 条件的只读复现，不代表黑墙一定已经应用；目标死亡/保护状态、前置条件或异步状态应用仍会影响结果。Normal/Charged/Bolt 仍是手动标签，不是原生 Bolt 识别器。

未增加包装，既有原方法执行次数和返回路径不变；同一个后效器原方法仍只调用一次。CHRONOS 的攻击选择、动能转换、已有投射物冻结/恢复代码不变。本次不实现技术武器弹道转换。

## 四、验证结果与尚待实机的检查

本地执行了 Lua 5.4 解析与模拟宿主测试；除了原有日志/生命周期/错误路径，新增四项分类验证均通过：

| 模拟命中 | `BlackwallFullCharge` |
|---|---|
| 远程，charge=0.75，flag=true | true |
| 远程，charge=0.75，flag=false | false |
| 远程，charge=1.0，flag=false | true |
| 非远程，charge=0.75，flag=true | false |

**0.75 只是测试输入，不是新增的游戏判定阈值。** 模拟测试不证明哪项是真实 Bolt。当前环境没有游戏 2.5、完整脚本缓存或 REDscript 编译器，未进行实际 REDscript 编译、CET 数据互通或游戏内回归测试。

实机先核对 `r6/logs/redscript_rCURRENT.log`，再做普通、部分蓄力且非 Bolt、满蓄力且非 Bolt、已由游戏表现确认的 Bolt 四组单发测试。对每组提供完整 session/trial、before/after、技能/插件配置与录像证据；别只截取一个充能数字。Boss 的已有上传上再测一次 Bolt，观察加速是否走蓄力分支。7 秒加速在 359 秒进度条中约为 1.94986 个百分点，实测进度差还包含两次命中之间按游戏模拟时间推进的部分。

如果 Bolt 样本 `PerfectlyCharged=true` 且 `BlackwallFullCharge=true`，但没有黑墙，应继续查 `can_execute`、目标/上传状态及安装版本，不应再放宽分类。若确认的 Bolt 样本 `PerfectlyCharged=false`，则保存完整日志继续追原版设置/传递路径，不能据单个样本就换成任意较低充能阈值。

只有取得原版实现链证据或足够实机观测后，才决定是否需要以及如何修改正式 V6.2。
