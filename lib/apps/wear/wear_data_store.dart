import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/season.dart';
import 'wear_models.dart';

class WearDataStore {
  static List<OutfitItem> outfits = [];
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

  /// 按场景 + 当前季节 + 温度过滤
  static List<OutfitItem> getFilteredOutfits({
    WearScene? scene,
    int? temperature,
  }) {
    final now = currentSeason;
    var result = List<OutfitItem>.from(outfits);
    if (scene != null && scene != WearScene.all) {
      result = result
          .where((o) => o.scene == scene || o.scene == WearScene.all)
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
      // 日常
      OutfitItem(name: 'T恤 + 牛仔裤', emoji: '👕', scene: WearScene.daily, seasons: summer, tempMin: 20),
      OutfitItem(name: '短袖 + 短裤', emoji: '🩳', scene: WearScene.daily, seasons: summer, tempMin: 25),
      OutfitItem(name: '连衣裙', emoji: '👗', scene: WearScene.daily, seasons: summer, tempMin: 22),
      OutfitItem(name: '卫衣 + 休闲裤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, tempMin: 10, tempMax: 22),
      OutfitItem(name: '衬衫 + 卡其裤', emoji: '👔', scene: WearScene.daily, seasons: springAutumn, tempMin: 12, tempMax: 24),
      OutfitItem(name: '针织衫 + 半裙', emoji: '🧶', scene: WearScene.daily, seasons: springAutumn, tempMin: 10, tempMax: 20),
      OutfitItem(name: '风衣 + 内搭', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn, tempMin: 5, tempMax: 18),
      OutfitItem(name: '毛衣 + 长裤', emoji: '🧶', scene: WearScene.daily, seasons: winter, tempMin: 0, tempMax: 12),
      OutfitItem(name: '羽绒服 + 牛仔裤', emoji: '🧥', scene: WearScene.daily, seasons: winter, tempMax: 5),
      OutfitItem(name: '大衣 + 高领毛衣', emoji: '🧥', scene: WearScene.daily, seasons: winter, tempMin: -10, tempMax: 8),
      OutfitItem(name: '长袖T恤 + 休闲裤', emoji: '👕', scene: WearScene.daily, seasons: springAutumn),
      // 运动
      OutfitItem(name: '运动套装', emoji: '🏃', scene: WearScene.sport, seasons: allYear),
      OutfitItem(name: '速干衣 + 短裤', emoji: '🏃', scene: WearScene.sport, seasons: summer, tempMin: 20),
      OutfitItem(name: '瑜伽服', emoji: '🧘', scene: WearScene.sport, seasons: allYear),
      OutfitItem(name: '跑步装', emoji: '👟', scene: WearScene.sport, seasons: allYear),
      OutfitItem(name: '篮球服', emoji: '🏀', scene: WearScene.sport, seasons: summer),
      OutfitItem(name: '游泳装', emoji: '🏊', scene: WearScene.sport, seasons: summer, tempMin: 24),
      OutfitItem(name: '抓绒外套 + 运动裤', emoji: '⛷️', scene: WearScene.sport, seasons: winter, tempMax: 8),
      // 正式
      OutfitItem(name: '西装套装', emoji: '🤵', scene: WearScene.formal, seasons: allYear),
      OutfitItem(name: '衬衫 + 西裤', emoji: '👔', scene: WearScene.formal, seasons: allYear),
      OutfitItem(name: '职业连衣裙', emoji: '👗', scene: WearScene.formal, seasons: allYear),
      OutfitItem(name: '小香风外套', emoji: '🧥', scene: WearScene.formal, seasons: springAutumn),
      OutfitItem(name: '大衣 + 正装裤', emoji: '🧥', scene: WearScene.formal, seasons: winter),
      // 约会
      OutfitItem(name: '碎花连衣裙', emoji: '🌸', scene: WearScene.date, seasons: summer),
      OutfitItem(name: '针织开衫 + 长裙', emoji: '🧶', scene: WearScene.date, seasons: springAutumn),
      OutfitItem(name: '衬衫 + 高腰裤', emoji: '👖', scene: WearScene.date, seasons: springAutumn),
      OutfitItem(name: '皮衣 + 裙装', emoji: '🧥', scene: WearScene.date, seasons: springAutumn),
      OutfitItem(name: '毛衣 + 百褶裙', emoji: '👗', scene: WearScene.date, seasons: winter),
      // 通勤
      OutfitItem(name: '衬衫 + 直筒裤', emoji: '👔', scene: WearScene.commute, seasons: allYear),
      OutfitItem(name: '西装外套 + 半裙', emoji: '🧥', scene: WearScene.commute, seasons: springAutumn),
      OutfitItem(name: '毛衣 + 西裤', emoji: '🧶', scene: WearScene.commute, seasons: winter),
      OutfitItem(name: '风衣 + 长裤', emoji: '🧥', scene: WearScene.commute, seasons: springAutumn),
      OutfitItem(name: '针织衫 + 阔腿裤', emoji: '👖', scene: WearScene.commute, seasons: springAutumn),
      OutfitItem(name: '羽绒服 + 西裤', emoji: '🧥', scene: WearScene.commute, seasons: winter),
      // 通配（无季节）
      OutfitItem(name: '卫衣 + 牛仔裤', emoji: '🧥', scene: WearScene.daily, seasons: allYear),
      OutfitItem(name: '棒球外套 + T恤', emoji: '🧥', scene: WearScene.daily, seasons: springAutumn),
    ];
  }
}
