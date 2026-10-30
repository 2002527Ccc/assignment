# 命运双插件槽与终曲外观问题交付

## 命运：使用这个新完整包

[下载页：Defy_TwoModSlots_NoScope.zip](Defy_TwoModSlots_NoScope.zip)

在 GitHub 文件页点击 Download raw file。

- 删除瞄具槽及对应瞄具生成列表，仍无枪口槽。
- 新增只属于命运的 `Items.TD_DefyTwoModBlueprint`，使用两个原版动能手枪 Collectible 普通插件槽，从 Common（1阶）开放。
- 两普通槽初始为空；隐藏 Crimestopper 不朽附件槽保留，不占普通槽。
- 保留此前升级成功判定、属性、商店、黑色枪身与固定激光外观；archive、XL 和 redscript 均与上一轮命运包逐字节相同。
- 不改原版全局蓝图或其他武器。

先在旧版本卸下命运已有的可拆卸瞄具，保存退出，停用旧命运完整包，再启用本完整包并部署。
已有武器附件没有自动迁移或删除脚本。如旧实例仍显示旧槽位，先用新生成的武器验证：

```lua
Game.AddToInventory("Items.Preset_Nue_Defy", 1)
```

这只新增一把武器，不会删除原枪。不要同时启用多份完整命运包。

## 终曲：外观尚未确认恢复

新上传的 `终曲.zip` 与首次上传文件逐字节一致，SHA-256 都是
`e99e7657ce18d44395fbb307893d4f7912de3eac40bcf28d4c883a9b49afcd62`。
仍然没有 `00_Finale_App_RefFix.archive`，因此它不是设计说明中的完整 V6.2 成功资源组合。
R4 石墨黑和主归档字节正确，不能证明游戏实际选择了正确模型；目前也不能排除用户本机部署覆盖问题。

本次没有修改、重新生成或声称恢复终曲材质，没有发布另一个“石墨黑已修复”的完整包。
需要用户提供此前颜色正常的 V6.2 整合包或 App 修复归档，才可继续核对成功加载链。
预期 App 补丁 SHA-256：`046453798a35a63fe99192743f06e88cb18fe63eb0ddd6d0a95cddcfd76b567a`。

### 可选：仅脚本覆盖包

[下载页：Finale_HitFilter_ScriptOnly.zip](Finale_HitFilter_ScriptOnly.zip)

它只有上一轮命中筛选修复的 `OneEyedTech.reds` 与说明，不含 archive、XL、YAML、四槽脚本。
它不修复颜色，也不包含 Bolt / PerfectlyCharged 后续设计修正。

只有先恢复颜色正常且脚本兼容的底包后，才叠加此补丁；让它只赢得 `OneEyedTech.reds` 冲突。
停用之前的“终曲_命中筛选修订版”完整整合包。底包脚本若有额外功能，先比较差异，不直接覆盖。

## 核验和源码

- [命运完整差异](Defy_two_slots.diff)
- [静态检查摘要](defy-validation.json)
- [终曲新旧上传对比](finale-upload-comparison.json)
- [命运源码与资源](source/defy/)
- [终曲仅脚本包源码](source/finale-script-only/)
- [交付哈希](SHA256_MANIFEST.json)

已执行 YAML 解析、独立蓝图/两槽/隐藏被动检查、非槽位属性及资源不变检查、原版 Common 解锁记录核对、ZIP CRC 和逐文件内容核对。
参考库提交为 `09a0a119c9614a76aecf71200b70913e79c4d574`，不等同用户实际游戏缓存。
没有进行游戏、TweakXL 导入、redscript 编译或旧武器实例迁移实测；不能把静态检查视为实机通过。
