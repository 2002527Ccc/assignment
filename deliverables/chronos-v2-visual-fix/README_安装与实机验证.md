# 克洛诺斯 V2 专属视觉修复 1.0.0

本包以用户提供的 `CHRONOS_V2_0_FULL_RUNTIME_RECOVERY_20261031.zip` 为运行基线，包含完整运行文件。战斗脚本、属性 YAML、生命损耗、时缓、技术武器和冷却功能保持原字节。唯一原有配置变更是关闭旧 V2 视觉分支，由新的专属视觉模块接管。

**已完成源码检查、私有资源格式校验和 Lua 模拟测试；未经过游戏 2.5 的实际 REDscript 编译、资源加载或画面验证。不能将本包称为已实机验证成功。**

## 安装前必须处理旧视觉文件

完全退出游戏，备份存档及现有 MOD。此 ZIP 无法安全删除其他 MOD 管理的文件，以下步骤不能省略：

1. 在 Vortex 禁用旧克洛诺斯完整包和旧 TEST01/TEST02 Lens 视觉包，再启用本完整修复包。避免重复 `.reds` 副本，`r6`、`bin`、`archive` 应直接落在游戏根目录。
2. 禁用参考 **TimeDilationVFX 的整个 MOD**。如果曾手动放入 `archive/pc/mod/TimeDilationVFX.archive` 或其 CET `mods/TimeDilationVFX` 目录，备份后移出游戏目录。原 archive 含原生主路径覆盖；只删作者 Lua 不足以排除全局影响。
3. 禁用先前“去蓝测试/Probe”MOD。TEST02 指向的 `r6/tweaks/chronos_vfx_probe.yaml` 不在附件中，不能核实其具体内容；其 README 明确承认全局影响其他 Sandy。如果手动装过该文件，备份后移出游戏目录。不要用本包与它叠加。
4. 保留克洛诺斯原有的 RED4ext、redscript、TweakXL、CET、Codeware 等前置。新增私有 archive 不依赖原 TimeDilationVFX 的 Lua 或 archive。
5. 部署后完整重启游戏并读取存档，让玩家附着回调重新执行；不要只在已加载存档中 Reload CET 脚本。

本包的新资源位于 `archive/pc/mod/Chronos13_PrivateVisuals.archive`，所有资源 depot 条目以 `ch13\` 开头，没有覆盖原版 `base\fx\player\time_dilation_vfx.effect`。

## 本次视觉行为

- `ch13_lens_radial_blur`：参考资源原有的径向模糊事件，保留原时序/循环配置。
- `ch13_lens_outlines`：参考资源的屏幕轮廓效果；轮廓不是空间折射的同义词。
- `ch13_lens_flash`：一次性启动扭曲候选。参考资源总长约 0.76 秒、粒子事件 0.5 秒，不强改为无限循环；其显式青色材质参数只在私有副本中改为中性灰，原强度、曲线和时间不变。
- 不分发参考包的主 ColorGrade effect，不使用全局 accepted-reasons 修改。只有严格检测到本体 `ChronosBridge.IsRunning` 且未暂停时，才请求私有效果和当前玩家原生颜色效果的实例抑制。

私有 flash 没有 ColorGrade 轨道，并不等于已经证实 shader 最终完全无色。它是启动一次性扭曲候选，**本包不宣称已实现或验证持续的空间扭曲场**。

## 为什么这次不再只有 START 日志

新的流程分开核实：

1. `entEffectDesc` 用 REDscript 的 `ResourceAsyncRef.SetPath` 构造真实资源引用。
2. 写入 `fx_player.effectDescs` 后，按原生名称和资源 hash 读回三个独有描述符。
3. 用 ResourceDepot token 检查三个顶层 effect 的 loaded/failed/pending 状态。
4. 只在注册足够且资源就绪后，每次激活请求一次播放；停止时只清理自己三个别名。
5. 只有实际资源检查确认原生目标含 ColorGrade，且私有播放请求均被接受后，才在克洛诺斯范围内请求停止该原生实例。

播放请求被接受不代表画面已出现；顶层 effect loaded 也不能证明全部材质/粒子依赖和 GPU 状态已经就绪。动态修改已初始化组件是否更新引擎内部 lookup，仍是实机检查项。

## 实机验证

1. 先检查最新 `r6/logs/redscript_rCURRENT.log`。若 `ChronosLensFX.reds` 编译失败，停止测试并回退，提交完整错误；CET 界面能打开不能代替编译检查。
2. 加载存档后，在 CET 热键设置绑定 **CHRONOS lens: registration/resource report**，或运行：

```lua
GetMod('MilitechChronosMK13Lens').diagnostics()
```

3. 先不启动克洛诺斯。预热和注册可以发生，但 `requested` 应为 false，不应出现私有播放或原生去色请求。
4. 启动克洛诺斯，在有明显直线/灯光/高对比边缘的场景观察。预期日志先后可见：`REGISTERED readback=3`、`PRIVATE_RESOURCES_LOADED count=3`、`PLAY_REQUESTED count=3`。附着阶段和资源异步完成的先后可能不同；所有日志仍标为 `rendered=UNVERIFIED`。
5. 诊断应显示 `registered=3`、`privateLoaded=3/3`、`requested=true`。`nativeGradesConfirmed` 和 `gradeStopRequested` 仅表示检查和请求，不能代替实际画面。若它们为零，去蓝尚未被确认，不能报成功。
6. 保持一次激活期间不操作，确认不再反复注册、FALLBACK、PLAY/STOP。日志只应在状态边沿变化，停止日志带明确 reason。暂停/菜单、真实玩家更换、卸载和实际退出属于合法状态变化。
7. 关闭克洛诺斯，确认私有效果结束；重复启停至少三次。启动 flash 每次只请求一次，不能每帧重放。
8. 换装其他斯安威斯坦，再单独测试克伦奇科夫。它们应保持原视觉，诊断不应有私有播放/去色请求。再测快速切换和加载存档；这些必须实机回归，静态隔离不能代替它们。
9. 同时核对原有生命损耗、时缓、战斗效果和技术/冷却功能。代码哈希保持不变不等于已完成游戏内回归。

请提供完整 `[CHRONOS LENS FIX]` 日志、编译日志和启停录像。不要只截取 Controller/Running 或 PLAY_REQUESTED 当作渲染证据。

## 错误状态的含义

- `REGISTRATION_BLOCKED`：实际描述符读回不足；最多重试 8 次，不会无限每帧播放。
- `RESOURCE_BLOCKED`：私有 archive/顶层资源未加载或超时；此激活不再反复加载，不应请求原生抑制。
- `NATIVE_GRADE_UNRESOLVED`：没有取得可检查的原生目标，或颜色检查失败；不会猜一个任意事件来停止，去蓝未获确认。
- `LATE_REGISTRATION`：错过玩家附着阶段后补注册；字段读回可能成功，但引擎内部缓存效果仍需完整重启/重载验证。
- `BRIDGE_ERROR`：视觉失败关闭并锁住本次激活，避免异常恢复时连续 PLAY/STOP；不关闭或重写本体战斗控制器。

## 卸载和回退

退出游戏，禁用本修复完整包并重新启用原完整包，再部署。确认 `ChronosLensFX.reds`、Lens 新目录和 `Chronos13_PrivateVisuals.archive` 不留手动副本；恢复原 V2 配置。优先使用测试前存档。若恢复旧 Probe/TimeDilationVFX，需接受它们原有的全局影响，不能将其表现归因于本专属修复。
