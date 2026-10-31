module Chronos.Localization
import Codeware.Localization.*

public class Provider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    if Equals(language, n"zh-cn") { return new Chinese(); }
    if Equals(language, n"en-us") { return new English(); }
    return null;
  }
  public func GetFallback() -> CName { return n"en-us"; }
}

public class English extends ModLocalizationPackage {
  protected func DefineTexts() {
    this.Text("Chronos-MK13-Name", "MILITECH MK.13 — CHRONOS");
    this.Text("Chronos-MK13-Description", "Experimental Militech curvature engine. 60% time slowdown; 120-second reserve; target full recharge: 1 real second. Active operation costs 1/13 maximum health per real second and can kill the user. Ranged deflection: 13% + 0.1 percentage point per Technical Ability. Mitigation Chance +28 points; Strength +7 points. Temporal correction covers observed recharge pools and tagged cyberware cooldowns only; universal coverage and Tech/Bolt compatibility remain unverified. No kill healing, kill extension or weapon damage bonuses.");
  }
}

public class Chinese extends ModLocalizationPackage {
  protected func DefineTexts() {
    this.Text("Chronos-MK13-Name", "MILITECH MK.13 — CHRONOS（军用科技13型·克洛诺斯）");
    this.Text("Chronos-MK13-Description", "军用科技实验型曲率引擎。时间减速60%，运行储备120秒，目标1现实秒完全充能。运行时每现实秒损失最大生命值的1/13，可致死。远程格挡：13%＋每点技术能力0.1个百分点。减伤几率＋28个百分点，减伤强度＋7个百分点。时标补偿仅覆盖已观测的充能池及带标签的义体冷却；全覆盖及技术武器/Bolt兼容性尚未实机验证。无击杀回血、击杀延时和武器伤害加成。");
  }
}
