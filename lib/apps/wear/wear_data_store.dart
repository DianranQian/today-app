import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/season.dart';
import 'wear_models.dart';

class WearDataStore {
  static List<OutfitItem> outfits = [];
  /// 避免近期重复（7 天）
  static bool avoidRecent = true;
  static List<WearHistoryRecord> history = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final outfitsJson = prefs.getString('wear_outfits');
    if (outfitsJson != null && outfitsJson.isNotEmpty) {
      try {
        final parsed = (jsonDecode(outfitsJson) as List)
            .map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
            .where((o) => o.name.isNotEmpty)
            .toList();
        outfits = parsed.isEmpty ? getDefaultOutfits() : parsed;
      } catch (_) {
        outfits = getDefaultOutfits();
      }
    } else {
      outfits = getDefaultOutfits();
    }

    avoidRecent = prefs.getBool('wear_avoid_recent') ?? true;

    final historyJson = prefs.getString('wear_history');
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        history = (jsonDecode(historyJson) as List)
            .map((e) => WearHistoryRecord.fromJson(e as Map<String, dynamic>))
            .where((h) => h.outfitName.isNotEmpty)
            .toList();
      } catch (_) {
        history = [];
      }
    }
    saveNow(prefs);
  }

  static Future<void> saveNow([SharedPreferences? prefsInstance]) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    prefs.setString('wear_outfits',
        jsonEncode(outfits.map((e) => e.toJson()).toList()));
    prefs.setString('wear_history',
        jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> save() => saveNow();

  /// 按场景 + 性别 + 人群 + 风格 + 当前季节 + 温度过滤
  static List<OutfitItem> getFilteredOutfits({
    WearScene? scene,
    WearGender? gender,
    WearGroup? group,
    WearStyle? style,
    int? temperature,
  }) {
    final now = targetSeason;
    var result = List<OutfitItem>.from(outfits);
    if (scene != null && scene != WearScene.all) {
      result = result
          .where((o) => o.scene == scene || o.scene == WearScene.all)
          .toList();
    }
    // 性别：通用款对任何性别都可用
    if (gender != null && gender != WearGender.unisex) {
      result = result
          .where((o) => o.gender == gender || o.gender == WearGender.unisex)
          .toList();
    }
    // 人群：通用款对任何人群都可用
    if (group != null && group != WearGroup.all) {
      result = result
          .where((o) => o.group == group || o.group == WearGroup.all)
          .toList();
    }
    // 风格：通用款对任何风格都可用
    if (style != null && style != WearStyle.all) {
      result = result
          .where((o) => o.style == style || o.style == WearStyle.all)
          .toList();
    }
    // 季节：无季节标注的视为四季通用
    result = result
        .where((o) => o.seasons.isEmpty || o.seasons.contains(now))
        .toList();
    // 温度区间过滤
    if (temperature != null) {
      result = result
          .where((o) =>
              (o.tempMin == null || temperature >= o.tempMin!) &&
              (o.tempMax == null || temperature <= o.tempMax!))
          .toList();
    }
    return result;
  }

  static List<OutfitItem> search(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(outfits);
    return outfits.where((o) => o.name.toLowerCase().contains(kw)).toList();
  }

  static Set<String> getRecentOutfitNames({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history
        .where((h) => h.date.isAfter(cutoff))
        .map((h) => h.outfitName)
        .toSet();
  }

  static int _randomIndex(int length) =>
      DateTime.now().microsecondsSinceEpoch % length;

  static OutfitItem pickFrom(List<OutfitItem> pool) {
    if (pool.isEmpty) throw StateError('pool is empty');
    return pool[_randomIndex(pool.length)];
  }

  static void addHistory(WearHistoryRecord record) {
    history.insert(0, record);
    if (history.length > 100) history = history.sublist(0, 100);
    save();
  }

  static void clearHistory() {
    history.clear();
    save();
  }

  static List<OutfitItem> getDefaultOutfits() {
    const summer = {Season.summer};
    const winter = {Season.winter};
    const springAutumn = {Season.spring, Season.autumn};
    const allYear = <Season>{};
    return [
      // ===== 日常（通用性别） =====
      OutfitItem(name: 'T恤 + 牛仔裤', emoji: '👕', scene: WearScene.daily, seasons: summer, tempMin: 20, style: WearStyle.retro),
      OutfitItem(name: '短袖 + 短裤', emoji: '🩳', scene: WearScene.daily, seasons: summer, tempMin: 25, style: WearStyle.casual),
      OutfitItem(name: '卫衣 + 休闲裤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, tempMin: 10, tempMax: 22, style: WearStyle.casual),
      OutfitItem(name: '衬衫 + 卡其裤', emoji: '👔', scene: WearScene.daily, seasons: springAutumn, tempMin: 12, tempMax: 24),
      OutfitItem(name: '针织衫 + 半裙', emoji: '🧶', scene: WearScene.daily, seasons: springAutumn, tempMin: 10, tempMax: 20, style: WearStyle.sweet),
      OutfitItem(name: '风衣 + 内搭', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, tempMin: 5, tempMax: 18),
      OutfitItem(name: '毛衣 + 长裤', emoji: '🧶', scene: WearScene.daily, seasons: winter, tempMin: 0, tempMax: 12),
      OutfitItem(name: '羽绒服 + 牛仔裤', emoji: '🧥', scene: WearScene.daily, seasons: winter, tempMax: 5, style: WearStyle.retro),
      OutfitItem(name: '大衣 + 高领毛衣', emoji: '🧥', scene: WearScene.daily, seasons: winter, tempMin: -10, tempMax: 8),
      OutfitItem(name: '长袖T恤 + 休闲裤', emoji: '👕', scene: WearScene.daily, seasons: springAutumn, style: WearStyle.casual),
      OutfitItem(name: '卫衣 + 牛仔裤', emoji: '🧥', scene: WearScene.daily, seasons: allYear, style: WearStyle.retro),
      OutfitItem(name: '棒球外套 + T恤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, style: WearStyle.trendy),
      // ===== 日常（女款） =====
      OutfitItem(name: '连衣裙', emoji: '👗', scene: WearScene.daily, seasons: summer, tempMin: 22, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '吊带裙', emoji: '👗', scene: WearScene.daily, seasons: summer, tempMin: 24, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '半身裙 + 雪纺衫', emoji: '👗', scene: WearScene.daily, seasons: springAutumn, tempMin: 15, tempMax: 26, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '针织开衫 + 半裙', emoji: '🧶', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '毛衣 + 长裙', emoji: '👗', scene: WearScene.daily, seasons: winter, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '大衣 + 打底裙', emoji: '🧥', scene: WearScene.daily, seasons: winter, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '阔腿裤 + 上衣', emoji: '👖', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.female),
      // ===== 日常（男款） =====
      OutfitItem(name: 'POLO衫 + 休闲裤', emoji: '👕', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.male, style: WearStyle.casual),
      OutfitItem(name: '衬衫 + 牛仔裤', emoji: '👔', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.male, style: WearStyle.retro),
      OutfitItem(name: '休闲西装 + T恤', emoji: '🤵', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.male, style: WearStyle.business),
      OutfitItem(name: '夹克 + 工装裤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, gender: WearGender.male, style: WearStyle.trendy),
      OutfitItem(name: '毛衣 + 牛仔裤', emoji: '🧶', scene: WearScene.daily, seasons: winter, gender: WearGender.male, style: WearStyle.retro),
      // ===== 运动 =====
      OutfitItem(name: '运动套装', emoji: '🏃', scene: WearScene.sport, seasons: allYear, style: WearStyle.casual),
      OutfitItem(name: '速干衣 + 短裤', emoji: '🏃', scene: WearScene.sport, seasons: summer, tempMin: 20, style: WearStyle.casual),
      OutfitItem(name: '瑜伽服', emoji: '🧘', scene: WearScene.sport, seasons: allYear, gender: WearGender.female, style: WearStyle.casual),
      OutfitItem(name: '跑步装', emoji: '👟', scene: WearScene.sport, seasons: allYear, style: WearStyle.casual),
      OutfitItem(name: '篮球服', emoji: '🏀', scene: WearScene.sport, seasons: summer, gender: WearGender.male),
      OutfitItem(name: '游泳装', emoji: '🏊', scene: WearScene.sport, seasons: summer, tempMin: 24),
      OutfitItem(name: '抓绒外套 + 运动裤', emoji: '⛷️', scene: WearScene.sport, seasons: winter, tempMax: 8, style: WearStyle.casual),
      // ===== 正式 =====
      OutfitItem(name: '西装套装', emoji: '🤵', scene: WearScene.formal, seasons: allYear, gender: WearGender.male, style: WearStyle.business),
      OutfitItem(name: '衬衫 + 西裤', emoji: '👔', scene: WearScene.formal, seasons: allYear, gender: WearGender.male, style: WearStyle.business),
      OutfitItem(name: '职业连衣裙', emoji: '👗', scene: WearScene.formal, seasons: allYear, gender: WearGender.female, style: WearStyle.business),
      OutfitItem(name: '西装外套 + 西裙', emoji: '🧥', scene: WearScene.formal, seasons: allYear, gender: WearGender.female, style: WearStyle.business),
      OutfitItem(name: '小香风外套', emoji: '🧥', scene: WearScene.formal, seasons: springAutumn, gender: WearGender.female),
      OutfitItem(name: '大衣 + 正装裤', emoji: '🧥', scene: WearScene.formal, seasons: winter, style: WearStyle.business),
      // ===== 约会 =====
      OutfitItem(name: '碎花连衣裙', emoji: '🌸', scene: WearScene.date, seasons: summer, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '针织开衫 + 长裙', emoji: '🧶', scene: WearScene.date, seasons: springAutumn, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '衬衫 + 高腰裤', emoji: '👖', scene: WearScene.date, seasons: springAutumn, gender: WearGender.female),
      OutfitItem(name: '皮衣 + 裙装', emoji: '🧥', scene: WearScene.date, seasons: springAutumn, gender: WearGender.female, style: WearStyle.retro),
      OutfitItem(name: '毛衣 + 百褶裙', emoji: '👗', scene: WearScene.date, seasons: winter, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: '衬衫 + 休闲西裤', emoji: '👔', scene: WearScene.date, seasons: springAutumn, gender: WearGender.male, style: WearStyle.business),
      OutfitItem(name: '卫衣 + 直筒裤', emoji: '🧥', scene: WearScene.date, seasons: springAutumn, gender: WearGender.male, style: WearStyle.casual),
      OutfitItem(name: '毛衣 + 牛仔裤', emoji: '🧶', scene: WearScene.date, seasons: winter, gender: WearGender.male, style: WearStyle.retro),
      // ===== 通勤 =====
      OutfitItem(name: '衬衫 + 直筒裤', emoji: '👔', scene: WearScene.commute, seasons: allYear),
      OutfitItem(name: '西装外套 + 半裙', emoji: '🧥', scene: WearScene.commute, seasons: springAutumn, gender: WearGender.female, style: WearStyle.business),
      OutfitItem(name: '毛衣 + 西裤', emoji: '🧶', scene: WearScene.commute, seasons: winter, style: WearStyle.business),
      OutfitItem(name: '风衣 + 长裤', emoji: '🧥', scene: WearScene.commute, seasons: springAutumn),
      OutfitItem(name: '针织衫 + 阔腿裤', emoji: '👖', scene: WearScene.commute, seasons: springAutumn),
      OutfitItem(name: '羽绒服 + 西裤', emoji: '🧥', scene: WearScene.commute, seasons: winter, style: WearStyle.business),
      // ===== 学生 =====
      OutfitItem(name: '校服风衬衫 + 休闲裤', emoji: '🎒', scene: WearScene.daily, seasons: springAutumn, group: WearGroup.student, style: WearStyle.casual),
      OutfitItem(name: '卫衣 + 运动裤', emoji: '🎒', scene: WearScene.daily, seasons: allYear, group: WearGroup.student, style: WearStyle.casual),
      OutfitItem(name: 'T恤 + 牛仔裤 + 帆布鞋', emoji: '👟', scene: WearScene.daily, seasons: summer, group: WearGroup.student, style: WearStyle.retro),
      OutfitItem(name: '针织背心 + 衬衫', emoji: '🧶', scene: WearScene.commute, seasons: springAutumn, group: WearGroup.student),
      // ===== 上班族 =====
      OutfitItem(name: '衬衫 + 西装裤', emoji: '👔', scene: WearScene.commute, seasons: allYear, group: WearGroup.office, style: WearStyle.business),
      OutfitItem(name: '衬衫 + 半裙', emoji: '👗', scene: WearScene.commute, seasons: allYear, group: WearGroup.office, gender: WearGender.female, style: WearStyle.sweet),
      OutfitItem(name: 'POLO衫 + 商务休闲裤', emoji: '👔', scene: WearScene.commute, seasons: allYear, group: WearGroup.office, gender: WearGender.male, style: WearStyle.business),
      // ===== 长辈 =====
      OutfitItem(name: '宽松棉麻套装', emoji: '🧓', scene: WearScene.daily, seasons: summer, group: WearGroup.elder),
      OutfitItem(name: '开衫毛衣 + 休闲裤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, group: WearGroup.elder, style: WearStyle.sweet),
      OutfitItem(name: '厚棉服 + 围巾', emoji: '🧣', scene: WearScene.daily, seasons: winter, group: WearGroup.elder),
      OutfitItem(name: '防滑鞋 + 舒适裤装', emoji: '👟', scene: WearScene.sport, seasons: allYear, group: WearGroup.elder),
      // ===== 儿童 =====
      OutfitItem(name: '卡通T恤 + 短裤', emoji: '🧸', scene: WearScene.daily, seasons: summer, group: WearGroup.child, style: WearStyle.casual),
      OutfitItem(name: '可爱卫衣 + 长裤', emoji: '🧸', scene: WearScene.daily, seasons: springAutumn, group: WearGroup.child, style: WearStyle.casual),
      OutfitItem(name: '羽绒背心 + 毛衣', emoji: '🧥', scene: WearScene.daily, seasons: winter, group: WearGroup.child),
      OutfitItem(name: '运动小套装', emoji: '🏃', scene: WearScene.sport, seasons: allYear, group: WearGroup.child, style: WearStyle.casual),
    ];
  }
}
