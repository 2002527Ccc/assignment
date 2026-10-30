本次修订：命运双插件槽 / 移除瞄具槽（2026-10-30）

1. 命运改用独立 Items.TD_DefyTwoModBlueprint，仅赋给 Items.Preset_Nue_Defy。
2. 两个普通插件槽采用原版 Power_Handgun_WeaponMod1_Collectible 与 2_Collectible；原版 unlockedBy=Common，蓝图元素无品质前置。
3. 蓝图中不包含 Scope 或 PowerModule；同时移除 slotPartList 的 HandgunPossibleScopesList 和 slotPartListPreset 的 HandgunAndRevolverScopesPartList。
4. 两普通槽设为空配件预设，不随机附送插件。IconicRangedWeaponModElement 和 TD_IconicPartPreset 保留，Crimestopper 内置不朽被动不占普通槽。
5. 保留上一轮命运升级成功判定，未改武器属性、商店、材质、模型、激光、归档或 XL；不修改原版蓝图、槽位或插件的全局记录。

安装：先在旧版本卸下命运已装的可拆卸瞄具，保存并退出游戏，停用旧命运包，启用本版并部署。不要同时启用两份完整命运包。
现有存档附件没有自动迁移/删除脚本；若旧枪缓存未更新，先用 Game.AddToInventory("Items.Preset_Nue_Defy", 1) 新生成一把验证。

验证范围：静态 YAML 解析、蓝图与槽位引用核对、隐藏不朽槽保留、原版 Common 解锁/插件兼容性参考、非槽位记录和资源字节一致性。
未运行游戏、REDscript 编译器或 TweakXL 导入器；两个槽的 UI、插件安装与旧枪更新仍需实机验证。
