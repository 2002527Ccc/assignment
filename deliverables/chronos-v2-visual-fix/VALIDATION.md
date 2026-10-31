# 验证报告：CHRONOS V2 VisualFix 1.0.0

本地已执行：

- `python3 tests/run_lua.py`：13 个纯 Lua 状态模拟场景通过；实际交付的 CET init/config/三效果生命周期集成模拟通过。覆盖注册读回0、资源pending/failed/timeout、部分请求失败回滚、不稳定字符串包装但原生身份相同、owner变化、bridge异常锁定、三效果每激活只播放一次、其他义体门控。
- `python3 resources/build_private_archive.py`：原 archive index CRC64、原 canonical CR2W header/table/buffer CRC32 回算匹配；私有 archive 重建后重新读取索引/边界/分段/SHA1/CRC/依赖和字节匹配。含四个 `ch13\` 私有资源、六个段，不含原主 ColorGrade 条目。flash 中性色变更为结构定位的单个参数，不改时间/曲线/扭曲强度。
- `python3 build_release.py`：生成完整安装 ZIP 和源码审查 ZIP；原始输入与修复源码不作为可删除输出。
- `python3 verify_release.py`：基线逐字节核对，唯一原配置变更是旧 V2 视觉开关；安装源码与审查源码一致；新增源码无战斗或全局 Tweak 写调用；资源 archive 重读；两个 ZIP 的 CRC、路径、内容及 SHA256 检查通过。
- 新 helper 相关签名/属性类型在固定 NativeDB `8d418f04128ce43a4f70a47689895bb0e7ecda7b` 的社区 2.5 RTTI 中存在，原始摘录见 `API_EVIDENCE.json`。
- 另取得社区反编译脚本固定 2.5 提交 `17c62d000310f8938beb9593b3892c6c4febeffb`，证实玩家附着回调注册在 super.OnGameAttached 之后；它没有提供 native FX 缓存更新的实现，详见 `SOURCE_TIMING_EVIDENCE.json`。

未执行、不可视为通过：

- 实际 REDscript 编译：当前没有游戏 2.5 的脚本缓存/编译环境。文本检查和 RTTI 签名核实不是编译。
- 实际 CET LuaJIT/RTTI 互通，以及引擎是否更新 fx_player 的内部 descriptor lookup。
- 游戏加载私有 archive 及原生 material/particle 依赖、GPU 编译和最终画面。
- 中性灰材质参数实际 shader 输出、启动扭曲是否可见、其他义体与战斗功能的游戏内回归。

因此 `REGISTERED`、`PRIVATE_RESOURCES_LOADED`、`PLAY_REQUESTED` 与 `rendered=UNVERIFIED` 分别报告。不能把请求成功当成视觉已经渲染。
