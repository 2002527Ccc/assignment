命运（Defy）——自定义 Crimestopper 被动 / 动能手枪

游戏内被动说明
概率瘫痪义体肢体、对静止或行动受限目标提高暴伤

游戏内武器描述
一切杀不死你的，只会让你收到一张昂贵的创伤小队医疗账单。

武器设定
名称：命运。
类型：动能手枪，保留鵺的直射方式、黑色枪身与激光瞄具。
基础参数：沿用 Pride 的基础属性，基础单发伤害额外乘以 1.10。
被动沿用 Crimestopper 的行动故障与条件暴伤机制，已移除拔枪后短暂提高暴击率的能力。
Crimestopper 不朽附件的常驻暴击伤害、换弹及瞄准参数与上一版相同。
初始品质：1 阶不朽，按原版不朽曲线逐档升级至 5++。
内置消音：已移除。
Treason：已移除武器记录、商店入口和独有资源；文件名沿用原包名称以便覆盖安装。

安装
需要安装并启用《往日之影》。框架前置沿用 ArchiveXL、TweakXL、RED4ext 和 redscript。
退出游戏，将压缩包中的 archive 与 r6 文件夹放进 Cyberpunk 2077 游戏根目录，覆盖同名文件。
使用模组管理器时，停用或卸载旧版后启用本版，避免两个版本同时加载。

获取与存档
保留威尔逊商店及限购一次规则，已有购买标记不会自动清除。
保留上一轮升级成功判定修复；本次仅调整可安装附件槽。升级页和实际扣料直接按显示阶数选择原版材料表。
旧枪在进入升级详情页及实际升级前会校准计数；升级后再次同步到下一档。
校准保留枪当时的显示阶级；已正常升阶的枪不会一律重置成 1 阶。
安装本版前先在旧版本中卸下命运已装的可拆卸瞄具，保存并退出游戏，再停用旧包并启用本包。
没有自动删除存档中旧配件的迁移脚本；旧实例若仍显示瞄具槽，可用下方指令新生成一把验证。
已安装 Cyber Engine Tweaks 时，可在控制台输入：

Game.AddToInventory("Items.Preset_Nue_Defy", 1)

初始 1 阶对应 Common，原版升级索引为 0；后续为 1+、2、2+、3、3+、4、4+、5、5+、5++。
恢复了由 WasItemUpgraded 驱动的原版品质曲线与 Plus 曲线，材料由原版 Upgrading 记录决定。
标准原版费用依次为：1→1+：75 个 1 阶材料；1+→2：40 个 2 阶材料；
2→2+：75 个 2 阶材料；2+→3：40 个 3 阶材料；
3→3+：75 个 3 阶材料；3+→4：40 个 4 阶材料；
4→4+：75 个 4 阶材料；4+→5：40 个 5 阶材料；
5→5+：75 个 5 阶材料；5+→5++：200 个 5 阶材料。
材料和基础数量读取当前游戏的原版 Upgrading 表，并保留原版升级费用减免。
本版仅为命运单独计算费用；修改 GetItemFinalUpgradeCost 的其他模组不保证可叠加。
本包不改全局材料表，也不退还此前已消耗的材料。
本包不会主动清理存档里已经存在的 Treason。

可继续调整
伤害倍率位于 r6\tweaks\treason_defy.yaml 的 Items.TD_PrideDamageBoost，当前 value: 1.10。
还可调整弹匣、射速、射程、后坐力、散布、触发概率、持续时间、升级成本、配件槽和商店库存。
当前使用命运专属 Items.TD_DefyTwoModBlueprint：两个普通动能手枪插件槽，初始1阶开放；没有瞄具槽和枪口槽。
槽位采用原版 Collectible 类型，不新增自定义槽位或通用 UI 包装；内置不朽被动仍占独立隐藏槽。

验证范围
已静态检查原版费用算法、升级前后计数、升级详情页与预览流程、10 段材料表、作用范围和 ZIP 完整性。
尚未使用游戏缓存编译 REDscript，不能将静态检查视为游戏内验证。
本次只修改槽位相关 YAML 和说明；原有 REDscript、归档及 XL 保持上一轮升级判定修订版字节。
未改动的模型、材质、图标和激光资源保持原始字节。
当前环境无法运行 Cyberpunk 2077，尚未进行游戏内实测。

升级修复参考
原版升级材料表：
https://github.com/CDPR-Modding-Documentation/Cyberpunk-Tweaks/blob/main/tweaks/base/gameplay/static_data/database/items/crafting/upgrade_data.tweak
原版不朽品质曲线引用：
https://github.com/CDPR-Modding-Documentation/Cyberpunk-Tweaks/blob/main/tweaks/base/gameplay/static_data/database/items/base_values.tweak
游戏脚本：CraftingSystem.GetItemFinalUpgradeCost、RPGManager.GetItemTierForUpgrades、PlayerPuppet.SetIconicWeaponsTier。
