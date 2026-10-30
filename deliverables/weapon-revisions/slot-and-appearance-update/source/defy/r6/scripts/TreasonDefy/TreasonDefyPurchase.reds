module TreasonDefy

@wrapMethod(PlayerPuppet)
protected cb func OnItemAddedToInventory(evt: ref<ItemAddedEvent>) -> Bool {
  let result: Bool;
  let destinyTierBeforeNativeInit: Float;
  let isDestiny: Bool = ItemID.IsValid(evt.itemID) && IsDefined(evt.itemData) && !ItemID.HasFlag(evt.itemID, gameEItemIDFlag.Preview) && ItemID.GetTDBID(evt.itemID) == t"Items.Preset_Nue_Defy";

  // Preserve the item's actual tier before vanilla converts iconic quality
  // into its saved upgrade counter. This also retains tiers on stash returns.
  if isDestiny {
    destinyTierBeforeNativeInit = ClampF(Cast<Float>(RoundF(evt.itemData.GetStatValueByType(gamedataStatType.Quality))) * 2.00 + Cast<Float>(RoundF(evt.itemData.GetStatValueByType(gamedataStatType.IsItemPlus))), 0.00, 10.00);
  };

  result = wrappedMethod(evt);

  if isDestiny {
    this.TD_ApplyDestinyUpgradeState(evt.itemData, destinyTierBeforeNativeInit);
  };

  if ItemID.IsValid(evt.itemID) && IsDefined(evt.itemData) {
    if evt.itemData.GetStatValueByType(gamedataStatType.ItemPurchasedAtVendor) > 0.00 {
      if ItemID.GetTDBID(evt.itemID) == t"Items.Preset_Nue_Defy" {
        GameInstance.GetQuestsSystem(this.GetGame()).SetFact(n"td_defy_purchased", 1);
      };
    };
  };

  return result;
}

// TweakXL runs ScriptableTweak callbacks after importing YAML records.
// Filter this weapon's ability only; leave the original Crimestopper untouched.
// Identify the draw buff by its status-effect ID instead of an unstable inline index.
public class TD_RemoveDrawCrit extends ScriptableTweak {
  protected cb func OnApply() -> Void {
    let source: array<TweakDBID> = FromVariant<array<TweakDBID>>(TweakDBInterface.GetFlat(t"Items.TD_IconicAbility.effectors"));
    let retained: array<TweakDBID>;
    let effectStatus: TweakDBID;

    for effectID in source {
      effectStatus = FromVariant<TweakDBID>(TweakDBInterface.GetFlat(effectID + t".statusEffect"));
      if effectStatus != t"BaseStatusEffect.Kappa_George_Swap_Buff" {
        ArrayPush(retained, effectID);
      };
    };

    if ArraySize(retained) != ArraySize(source) {
      TweakDBManager.SetFlat(t"Items.TD_IconicAbility.effectors", ToVariant(retained));
      TweakDBManager.UpdateRecord(t"Items.TD_IconicAbility");
    };
  }
}

// Read the actual displayed tier. Old saves can contain a stale upgrade
// counter even though this pistol still displays Tier 1.
@addMethod(RPGManager)
public final static func TD_GetDestinyTier(itemData: wref<gameItemData>) -> Float {
  return ClampF(Cast<Float>(RoundF(itemData.GetStatValueByType(gamedataStatType.Quality))) * 2.00 + Cast<Float>(RoundF(itemData.GetStatValueByType(gamedataStatType.IsItemPlus))), 0.00, 10.00);
}

@addMethod(PlayerPuppet)
public final func TD_EnsureDestinyUpgradeState(itemData: wref<gameItemData>) -> Void {
  let tier: Float;
  if !IsDefined(itemData) || ItemID.GetTDBID(itemData.GetID()) != t"Items.Preset_Nue_Defy" {
    return;
  };
  if ItemID.HasFlag(itemData.GetID(), gameEItemIDFlag.Preview) {
    return;
  };
  tier = ClampF(Cast<Float>(RoundF(itemData.GetStatValueByType(gamedataStatType.Quality))) * 2.00 + Cast<Float>(RoundF(itemData.GetStatValueByType(gamedataStatType.IsItemPlus))), 0.00, 10.00);
  this.TD_ApplyDestinyUpgradeState(itemData, tier);
}

@addMethod(PlayerPuppet)
public final func TD_ApplyDestinyUpgradeState(itemData: wref<gameItemData>, tier: Float) -> Void {
  let stats: ref<StatsSystem>;
  let modifier: ref<gameStatModifierData>;
  if !IsDefined(itemData) || ItemID.GetTDBID(itemData.GetID()) != t"Items.Preset_Nue_Defy" {
    return;
  };
  if ItemID.HasFlag(itemData.GetID(), gameEItemIDFlag.Preview) {
    return;
  };
  stats = GameInstance.GetStatsSystem(this.GetGame());

  // Remove legacy fixed-quality offsets and stale upgrade counters together.
  // Rebuild only this instance using the two native iconic progression curves.
  stats.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.Quality, true);
  stats.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.IsItemPlus, true);
  stats.RemoveAllModifiers(itemData.GetStatsObjectID(), gamedataStatType.WasItemUpgraded, true);

  modifier = RPGManager.CreateStatModifier(gamedataStatType.WasItemUpgraded, gameStatModifierType.Additive, ClampF(tier, 0.00, 10.00));
  stats.AddSavedModifier(itemData.GetStatsObjectID(), modifier);
  modifier = RPGManager.CreateStatModifierUsingCurve(gamedataStatType.Quality, gameStatModifierType.Additive, gamedataStatType.WasItemUpgraded, n"quality_curves", n"iconic_upgrades_amount_to_quality");
  stats.AddSavedModifier(itemData.GetStatsObjectID(), modifier);
  modifier = RPGManager.CreateStatModifierUsingCurve(gamedataStatType.IsItemPlus, gameStatModifierType.Additive, gamedataStatType.WasItemUpgraded, n"quality_curves", n"iconic_upgrades_amount_to_plus");
  stats.AddSavedModifier(itemData.GetStatsObjectID(), modifier);

}

// Calculate this weapon's costs directly from its visible tier. Do not rely
// on an already-saved WasItemUpgraded value, and do not mutate tooltip queries.
@wrapMethod(CraftingSystem)
public final const func GetItemFinalUpgradeCost(itemData: wref<gameItemData>) -> array<IngredientData> {
  let ingredients: array<IngredientData>;
  let reduction: Float;
  let i: Int32;
  if !IsDefined(itemData) || ItemID.GetTDBID(itemData.GetID()) != t"Items.Preset_Nue_Defy" {
    return wrappedMethod(itemData);
  };

  ingredients = this.GetItemBaseUpgradeCost(itemData.GetItemType(), RPGManager.GetItemTierForUpgrades(RPGManager.TD_GetDestinyTier(itemData)));
  reduction = GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(this.GetPlayerCraftBook().GetOwner().GetEntityID()), gamedataStatType.UpgradingCostReduction);
  i = 0;
  while i < ArraySize(ingredients) {
    ingredients[i].baseQuantity = ingredients[i].quantity;
    if reduction > 0.00 {
      ingredients[i].quantity = Cast<Int32>(Cast<Float>(ingredients[i].quantity) * (1.00 - reduction));
    };
    i += 1;
  };
  return ingredients;
}

// Repair before vanilla reads oldVal (which happens before it requests costs),
// Commit the next tier only after the native upgrade counter has advanced.
@wrapMethod(CraftingSystem)
private final func UpgradeItem(owner: wref<GameObject>, itemID: ItemID) -> Void {
  let player: ref<PlayerPuppet>;
  let itemData: wref<gameItemData>;
  let afterData: wref<gameItemData>;
  let tier: Float;
  let nativeAfter: Float;
  if ItemID.GetTDBID(itemID) != t"Items.Preset_Nue_Defy" {
    wrappedMethod(owner, itemID);
    return;
  };
  player = owner as PlayerPuppet;
  itemData = GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemData(owner, itemID);
  if !IsDefined(player) || !IsDefined(itemData) || ItemID.HasFlag(itemID, gameEItemIDFlag.Preview) {
    wrappedMethod(owner, itemID);
    return;
  };
  tier = RPGManager.TD_GetDestinyTier(itemData);
  player.TD_ApplyDestinyUpgradeState(itemData, tier);
  wrappedMethod(owner, itemID);

  // Native UpgradeItem returns Void and may fail or replace item data.
  afterData = GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemData(owner, itemID);
  if !IsDefined(afterData) {
    return;
  };
  nativeAfter = afterData.GetStatValueByType(gamedataStatType.WasItemUpgraded);
  if nativeAfter > tier + 0.50 {
    player.TD_ApplyDestinyUpgradeState(afterData, MinF(tier + 1.00, 10.00));
  };
}

// Prepare an old item before the screen checks the maximum tier or temporarily
// increments the upgrade counter to draw its right-hand comparison tooltip.
@wrapMethod(UpgradingScreenController)
private final func UpdateItemPreviewPanel(const selectedItem: script_ref<InventoryItemData>) -> Void {
  let itemData: wref<gameItemData> = InventoryItemData.GetGameItemData(selectedItem);
  let player: ref<PlayerPuppet>;
  if IsDefined(itemData) && ItemID.GetTDBID(itemData.GetID()) == t"Items.Preset_Nue_Defy" {
    player = GetPlayer(this.m_Game);
    if IsDefined(player) {
      player.TD_EnsureDestinyUpgradeState(itemData);
    };
  };
  wrappedMethod(selectedItem);
}
