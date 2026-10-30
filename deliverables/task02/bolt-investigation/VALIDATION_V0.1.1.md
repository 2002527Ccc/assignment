# 验证范围：诊断 v0.1.1

本地检查结果：

- `python3 v0.1.1/test_lua.py`：Lua 5.4 解析、模拟 CET 生命周期/日志/异常路径测试通过；新增四种命中快照的 V6.2 分类结果符合条件。测试数据不是实机 Bolt 日志。
- `python3 verify_diagnostics.py`：安装源码与 source 副本一致；原 CHRONOS 选择/动能转换/冻结代码与 v0.1.0 逐字节一致；后效器包装仅增加两项只读快照、原方法调用仍一次；事件类只增加两个 Bool 字段；两个 ZIP 的 CRC/内容检查通过；原来已发布的 18 个 Task02 文件均未更改。
- NativeDB 的 2.5 数据更新提交与接口原始条目已核实，证据见 `NATIVE_API_EVIDENCE.json`。确认接口存在不等于确认 Bolt 的标志设置路径。
- 完整 V6.2 基线包和其解压文件在本次处理后仍逐字节一致；诊断安装包不包含任何正式终曲脚本/YAML、archive、xl，也不包含原 CHRONOS CET 配置/核心。

未执行且不能声称通过：

- REDscript 实际编译（缺少游戏 2.5、完整脚本缓存和编译器）。
- 游戏内 CET/REDscript 数组与新增字段互通。
- 原生 Bolt 是否携带 PerfectlyCharged、在终曲 PostProcess 阶段是否保留。
- 黑墙首发、普通/Boss 进度、外观/语音/插件槽等游戏行为回归。
- 新补丁在 Vortex 的实际部署与卸载、存档序列化兼容性。

本次交付是调查报告和只读诊断增强，不是已验证的正式 MOD 修复。不要将 `NativeBoltFlag=UNAVAILABLE` 当作 false，也不要把手动 Bolt 标签或模拟测试当作原生识别证据。
