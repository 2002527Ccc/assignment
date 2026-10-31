# 克洛诺斯：完整原版视觉仅去蓝的重设计调查

状态：**尚未实现，不生成新 FULL，不将 1.0.0 的第三方替代效果称为原版完整保留。**

本次继续使用 `chronos-v2-visual-fix` 分支。1.0.0 源码、资源、FULL ZIP 和 Source ZIP 全部冻结作为回退；本次只新增调查材料。原有战斗代码、数值及本体功能没有修改。

## 一、为什么 1.0.0 不满足新目标

1.0.0 停止含 ColorGrade 的原生事件，再同时启动第三方径向模糊、轮廓、flash。它能实现候选视觉组合，不能证明保留真正原版的轨道全集、强度、曲线、循环或退出时序。

具体缺口包括：

- 资源来自用户提供的 TimeDilationVFX.archive。depot 路径以 `base\` 开头不代表字节就是干净的 2.5 原件。
- 对任意 ColorGrade 的 Bool 检查不说明该轨道只含蓝色色调。
- Lua 的 `IsRunning` 边沿不是原生 VFX 调度边沿；在它变 false 时清理不能证明原生退出过渡已完成。
- `StopOwn` 先 BreakEffectLoop，随即 StopEffectEvent，可能直接截断应继续播放的 loop-break/退出尾段。
- 单次同时启动三个替代资源，不能重现尚未取得的原版启动/持续/退出事件图。

因此本次停止沿用“原生事件硬停 + 三资源替代”的实现思路；没有通过调整 flash 长度、强度或循环来冒充原版。

## 二、已证实的原版 2.5 脚本路径

来源是社区反编译脚本固定提交 `17c62d000310f8938beb9593b3892c6c4febeffb`，提交标注 2.5。它不是本机实测；精确文件哈希、链接、行号和摘要见 `VANILLA_VFX_PATH_TRACE.json`。

- [timeDilationTransitions.swift](https://codeberg.org/adamsmasher/cyberpunk/src/commit/17c62d000310f8938beb9593b3892c6c4febeffb/cyberpunk/player/psm/timeDilationTransitions.swift) 第 196–210 行：Sandevistan 进入时设置 `Sandevistan` 相机曲线，并调用原生 `TimeSystem.SetTimeDilation`，reason 为 `sandevistan`；没有在这里直接 StartEffectEvent。
- 同文件第 213–231 行：正常/强制/拍照退出通过 `SandevistanEaseOut` 与原生 unset 处理。
- 同文件第 97–115 行与玩家脚本第 3923–3935 行：存在可延后发送的 cleanup 事件和原生清理。这里的延迟不是可随意复制为 Lua 固定一秒计时的通用规则。
- 同文件第 366–410 行：Kerenzikov 使用独立的 `kereznikov` reason 以及自己的相机和 ease 曲线。

Tweak 镜像 `CDPR-Modding-Documentation/Cyberpunk-Tweaks@09a0a119c9614a76aecf71200b70913e79c4d574` 中的 accepted-reasons 配置只列理由数组，没有给出完整效果二进制路径或轨道图；该仓库 README 也未明确版本。原生 Sandy buff 的 status-effect VFX 列表不等于 TimeSystem 屏幕 VFX 全集。

**由此可以确认：后续方案必须保留原生调度及上下文，而不是按 CET 轮询结果重新播放类似效果。** 这些脚本不能替代引擎内部 VFX 调度实现或二进制资源本身。

## 三、接口调查：可用候选与不能冒认的能力

固定 2.5 社区 NativeDB、Codeware 与 ArchiveXL 的精确提交及原始声明见 `API_FEASIBILITY.json`。

### 1. 没有找到可用的实例级单轨开关

所检查的 2.5 `FxInstance` 导出包括 Kill、BreakLoop、SetBlackboardValue 等，没有公开的“关闭指定 ColorGrade track”接口。GameObjectEffectHelper.StartEffectEvent 不返回可操纵的 FxInstance。

这不等于证明游戏引擎绝对没有内部能力；它表示当前已核实的脚本接口不足以直接实现该要求。不能杜撰 `DisableColorGrade()` 或猜黑板键名。

### 2. Clone 确实存在，但不能据此直接完成资源绑定

Codeware `ISerializable.Clone()` 是真实接口。其公开实现调用引擎 Clone，没有公开完整深复制保证，也没有已核实的“将任意克隆 worldEffect 注册为私有 depot path/token”接口。仅改 clone 的属性，不能证明 RARef 会加载这个克隆。

### 3. ArchiveXL resource.copy 是更合适的私有副本候选

ArchiveXL 源码将 `copy` 的私有 loader key 与原字节来源分开处理，区别于会改写 loader 请求路径的 `link`。这为“加载真正原版的完整私有副本，仅修改其局部颜色参数”提供了候选机制。

但还没有实测证明所有可变子节点与缓存对象独立；`resource.scope` 也不是自动按义体实例隔离的条件。它们不能单独解决 CHRONOS 专属路由和退出尾段。

### 4. 不能删除整个 ColorGrade 类别

2.5 `effectTrackItemColorGrade` 同时包含 `contrast`、`saturate`、`brightness`、`lutWeight` 和 SDR/HDR LUT。ColorGradeV2 还包含 hue、lift/gamma/gain 等其他参数。

只有取得真实原件，才能确定蓝色来自哪个 LUT、权重、材质参数或其他原生处理；不能把所有 ColorGrade 对象删掉后声称只删除蓝色。如果使用黑板控制，也必须先确认该键确实只控制蓝色贡献。

## 四、当前缺少的必要输入

工作区没有游戏 2.5 的原版 archive 内容。现有 `.effect`/`.particle` 均来自第三方参考包或 1.0.0 私有副本，没有一份能够认证为干净的原版 FX 原件。

因此当前无法列出“已经实际修改的真正原版轨道”：**数量为零**。没有修改正式 MOD，没有制作声称已完整保留原版的新 FULL。

请按 `REQUIRED_VANILLA_INPUTS_zh.md` 从本机干净 2.5 游戏 archive 导出相关特效及依赖，保留 depot 目录结构并记录来源。当前只有第三方给出的候选路径，不能把它当作已确认的原版完整清单。

## 五、取得原件后的最小实现与验收条件

1. 建立真实原版资源图：进入、持续、退出、外部粒子/材质/LUT、循环、evaluators 和引用路径。
2. 确认蓝色贡献。优先只禁用其局部 LUT/颜色参数；对比度、亮度、其他颜色处理不能无依据删除。
3. 使用完整私有文件副本，或经对象身份/缓存隔离验证的 resource.copy。不能修改原 ResourceDepot 共享图，不能全局覆盖原版路径。
4. 验证 CHRONOS 专属资源路由能沿用原生进入/持续/退出请求、相机曲线和上下文。无法证明时序不变，就不能完成此方案，也不能退回“Stop + 替代播放”却声称一致。
5. 比较原版与私有副本：非蓝轨道、强度、时间、循环、RUID、曲线及原生生命周期应保持一致；允许差异只能是已定位的蓝色贡献、必要私有引用和文件校验。
6. 做同场景前后录像、SDR/HDR与相同画面设置下对照；正常/强制退出、暂停、加载、快速切换以及其他 Sandy/Kerenzikov 均需验证。

取得原件是必要条件，不是“收到后必然能立即完成”的承诺。实例路由、缓存隔离与原生退出时序仍需分别证实。只有这些条件满足后才生成新 FULL。
