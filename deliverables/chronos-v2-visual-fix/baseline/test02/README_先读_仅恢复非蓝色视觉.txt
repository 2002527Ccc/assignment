CHRONOS V2.0 原版非蓝色特效 TEST02（仅CET视觉模块）

这是 TEST01 的初始化时序修正版本，不是完整克洛诺斯。
根本变化：在 PlayerPuppet.PlayerAttachedCallback 阶段尽早注册
    time_dilation_vfx_radial_blur
    time_dilation_vfx_outlines
两个原版候选特效，而不是在克洛诺斯开启之后才注册。

安装：
1 完全退出游戏。
2 复制本包 bin 文件夹到游戏根目录，覆盖同名 MilitechChronosMK13Lens/init.lua。
3 保留此前成功去蓝的 r6/tweaks/chronos_vfx_probe.yaml。
4 保持 bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13V2/config.lua 的 enabled.visual=false。
5 进入游戏，读取存档，启动/关闭克洛诺斯并观察。

检查 CET 控制台日志：
  [CHRONOS LENS] TEST02 loaded
  [CHRONOS LENS] ATTACH: native FX descriptors prepared before normal gameplay
  [CHRONOS LENS] START: requested ...
如果只有 START 而没有可见效果，不意味着未调用；这些原版独立资源可能本身不包含
你需要的完整畸变。需要通过 WolvenKit 检查原版 time_dilation_vfx.effect 的颜色
和折射轨道，不能在没有源 .effect 文件时保证只删颜色。

卸载：删除 bin/x64/plugins/cyber_engine_tweaks/mods/MilitechChronosMK13Lens。
本包不会修改克洛诺斯的时缓、扣血、CD、射击补偿等功能。
保留的去蓝 YAML 仍全局影响所有斯安威斯坦；不是最终专用实现。
仅完成静态检查，未经过 2.5 实机验证。
