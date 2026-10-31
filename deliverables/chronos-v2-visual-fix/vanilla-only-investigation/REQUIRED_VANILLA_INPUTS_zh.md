# 需要的真正原版 2.5 视觉资源

目的：取得可检查的原版资源，确认蓝色贡献和完整非蓝轨道；不是再生成一组替代特效。

## 先排除来源污染

1. 保留当前存档、MOD及配置备份。
2. 使用 WolvenKit 的 Asset Browser，从游戏基础/官方补丁 archive 选择资源，查看来源，确认不是 `archive/pc/mod` 下的 TimeDilationVFX 或其他覆盖包。
3. 记录游戏实际版本和所选源 archive 的文件名。能够提供该 archive 的 SHA256 更好；单凭资源 basename 或第三方作者说明不能认证原件。

## 需要导出的内容

- 原版 Sandevistan/TimeDilation 所使用的 `.effect` 资源。
- 它们实际引用的 `.particle`、材质/材质实例、LUT、曲线等依赖，保持原 depot 路径。
- 原始二进制优先；如能同时导出 CR2W JSON，一并提供，便于逐属性比较。将加入空白工程后的相关 `source/archive` 目录打包即可。
- 如无法确认哪个资源由原生系统调用，再补充玩家 `fx_player.effectDescs` 的名称/路径清单或相应实体资源中这部分配置；无需先导出整个角色模型依赖。

可以在 Asset Browser 检索 `time_dilation`、`sandevistan`。第三方包给出的 `base\fx\player\time_dilation_vfx.effect` 只是候选名，**不是已认证的原版路径或全集**；请依据实际原版 archive 内容和引用关系选择。

请提供一个包含这些小资源、目录结构和来源说明的 ZIP。相关依赖如果体积很大，可以先给原始 effect 和依赖清单，再补必要文件。

## 如需录制“原版视觉基线”

以下仅是建立原版对照的方法，不是正式修复，也不要求改动战斗功能：

- 保留 CHRONOS 本体核心和数值；在测试副本中暂时停用 1.0.0 的 Lens 模块，并保持 V2 旧视觉分支 `enabled.visual=false`，避免任一去色模块停止原生效果。
- 移除第三方 TimeDilationVFX 的 Lua/archive 及全局去蓝 Probe 的影响，完整重启后再观察。1.0.0 完整包与核心是一起部署的，处理 Lens 时不要误删核心两个 CET 目录。
- 在同场景、相同运动模糊/色散/HDR等图形设置下，录制启动、持续运动和完整退出过渡。录像是视觉对照，不能替代原始轨道数据。

如果不希望动当前部署，可以先仅从 WolvenKit 原版 archive 导出资源；不必为了取文件先在游戏里做新的测试。
