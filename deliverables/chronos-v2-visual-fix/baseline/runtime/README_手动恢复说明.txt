克洛诺斯 V2.0 全部运行文件恢复包（原始文件原样提取）

用途：仅当安装后的游戏目录缺失 ChronosTemporalCompensation.reds、其他REDscript、TweakXL YAML、CET脚本时使用。
数据来源：MILITECH_CHRONOS_MK13_V2_0_R1B_BASED.zip；不含任何修改后的代码、数值或修复程序。

【建议优先】
1. 退出游戏。
2. 在Vortex中对 V2.0 执行重新部署（Deploy Mods），再验证下列路径。若文件都存在，不需要手动复制本包。

【如仍缺失，手动恢复】
1. 退出游戏。
2. 备份游戏根目录下同名文件（如存在）。
3. 解压本ZIP，将 r6 和 bin 两个文件夹复制至真实游戏根目录：
   C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\
   选择合并文件夹；不要多套一层CHRONOS_V2_0_FULL_RUNTIME...文件夹。
4. 检查：
   r6\scripts\ChronosTemporalCompensation.reds
   r6\scripts\ChronosV2Queries.reds
   r6\scripts\ChronosV2VisualQueries.reds
   r6\tweaks\chronos\chronos_mk13.yaml
   bin\x64\plugins\cyber_engine_tweaks\mods\MilitechChronosMK13\init.lua
   bin\x64\plugins\cyber_engine_tweaks\mods\MilitechChronosMK13V2\init.lua
5. 启动游戏并检查REDscript、TweakXL最新日志。成功后在CET控制台查询
   print(TweakDB:GetRecord("Items.MilitechChronosMk13"))
   再查询静态桥接（不会在失败时中断控制台）：
   print("ChronosBridge type", type(ChronosBridge))
   如果输出仍是nil，则应核对当次REDscript日志和CET的scripting.log。

警告：本包用于手工恢复。Vortex之后Purging或Deploying可能移除手工放入的文件。建议解决Vortex部署冲突后改用管理器统一安装；不要同时装多个旧版Chronos。
