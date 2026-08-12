import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/scheme_store.dart';
import 'go_models.dart';

class GoDataStore {
  static List<PlaceItem> places = [];
  /// 避免近期重复（7 天）
  static bool avoidRecent = true;
  static List<GoHistoryRecord> history = [];

  static Future<void> load() async {
    await SchemeStore.migrateLegacy('go');
    final scheme = await SchemeStore.current('go');
    final prefs = await SharedPreferences.getInstance();

    final placesJson = prefs.getString(SchemeStore.dataKey('go', scheme, 'places'));
    var json = placesJson;
    if ((json == null || json.isEmpty) && scheme == SchemeStore.defaultSchemeName('go')) {
      json = prefs.getString('go_places');
    }
    if (json != null && json.isNotEmpty) {
      try {
        final parsed = (jsonDecode(json) as List)
            .map((e) => PlaceItem.fromJson(e as Map<String, dynamic>))
            .where((p) => p.name.isNotEmpty)
            .toList();
        places = parsed.isEmpty ? getDefaultPlaces() : parsed;
      } catch (_) {
        places = getDefaultPlaces();
      }
    } else {
      places = getDefaultPlaces();
    }

    avoidRecent = prefs.getBool('go_avoid_recent') ?? true;

    final historyJson = prefs.getString('go_history');
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        history = (jsonDecode(historyJson) as List)
            .map((e) => GoHistoryRecord.fromJson(e as Map<String, dynamic>))
            .where((h) => h.placeName.isNotEmpty)
            .toList();
      } catch (_) {
        history = [];
      }
    }
    saveNow(prefs);
  }

  static Future<void> saveNow([SharedPreferences? prefsInstance]) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final scheme = SchemeStore.cachedCurrent('go');
    prefs.setString(SchemeStore.dataKey('go', scheme, 'places'),
        jsonEncode(places.map((e) => e.toJson()).toList()));
    prefs.setString('go_history', jsonEncode(history.map((e) => e.toJson()).toList()));
  }

  static Future<void> save() => saveNow();

  /// 随机池去处列表：仅当前方案时返回内存数据；多方案时合并（按 name 去重）
  static Future<List<PlaceItem>> loadRandomPool() async {
    final raw = await SchemeStore.rawPoolItems('go', 'places');
    if (raw == null) return List<PlaceItem>.from(places);
    final items = raw.map((m) => PlaceItem.fromJson(m)).toList();
    return items.isEmpty ? List<PlaceItem>.from(places) : items;
  }

  static List<PlaceItem> getFilteredPlaces({PlaceType? type, List<PlaceItem>? pool}) {
    var result = List<PlaceItem>.from(pool ?? places);
    if (type != null && type != PlaceType.all) {
      result = result.where((p) => p.type == type || p.type == PlaceType.all).toList();
    }
    return result;
  }

  static List<PlaceItem> search(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(places);
    return places.where((p) => p.name.toLowerCase().contains(kw)).toList();
  }

  static Set<String> getRecentPlaceNames({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history
        .where((h) => h.date.isAfter(cutoff))
        .map((h) => h.placeName)
        .toSet();
  }

  static int _randomIndex(int length) =>
      DateTime.now().microsecondsSinceEpoch % length;

  static PlaceItem pickFrom(List<PlaceItem> pool) {
    if (pool.isEmpty) throw StateError('pool is empty');
    return pool[_randomIndex(pool.length)];
  }

  static void addHistory(GoHistoryRecord record) {
    history.insert(0, record);
    if (history.length > 100) history = history.sublist(0, 100);
    save();
  }

  static void clearHistory() {
    history.clear();
    save();
  }

  static void resetToDefault() {
    places = getDefaultPlaces();
    history.clear();
    save();
  }

  static List<PlaceItem> getDefaultPlaces() {
    return [
      // 吃饭
      PlaceItem(name: '火锅店', emoji: '🍲', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '烧烤店', emoji: '🍢', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '日料店', emoji: '🍣', type: PlaceType.eat, priceTier: 3),
      PlaceItem(name: '川菜馆', emoji: '🌶️', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '粤菜馆', emoji: '🥟', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '面馆', emoji: '🍜', type: PlaceType.eat, priceTier: 1),
      PlaceItem(name: '自助餐厅', emoji: '🍽️', type: PlaceType.eat, priceTier: 3),
      PlaceItem(name: '粤式早茶', emoji: '🥠', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '韩式烤肉店', emoji: '🥩', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '泰式餐厅', emoji: '🍛', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '西餐厅', emoji: '🍴', type: PlaceType.eat, priceTier: 3),
      PlaceItem(name: '小酒馆', emoji: '🍷', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '深夜食堂', emoji: '🌙', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '甜品店', emoji: '🍰', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '咖啡馆', emoji: '☕', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '奶茶店', emoji: '🧋', type: PlaceType.eat, priceTier: 1),
      PlaceItem(name: '蛋糕店', emoji: '🎂', type: PlaceType.eat, priceTier: 2),
      PlaceItem(name: '麻辣烫店', emoji: '🌶️', type: PlaceType.eat, priceTier: 1),
      PlaceItem(name: '砂锅粥店', emoji: '🥣', type: PlaceType.eat, priceTier: 1),
      PlaceItem(name: '海鲜排挡', emoji: '🦞', type: PlaceType.eat, priceTier: 3),
      // 逛街
      PlaceItem(name: '购物中心', emoji: '🛍️', type: PlaceType.shop, priceTier: 2),
      PlaceItem(name: '奥特莱斯', emoji: '🏷️', type: PlaceType.shop, priceTier: 2),
      PlaceItem(name: '步行街', emoji: '🚶', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '夜市', emoji: '🏮', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '跳蚤市场', emoji: '🧺', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '花鸟市场', emoji: '🌺', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '书店', emoji: '📚', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '文具店', emoji: '✏️', type: PlaceType.shop, priceTier: 1),
      PlaceItem(name: '进口超市', emoji: '🛒', type: PlaceType.shop, priceTier: 2),
      PlaceItem(name: '菜市场', emoji: '🥬', type: PlaceType.shop, priceTier: 1),
      // 公园
      PlaceItem(name: '城市公园', emoji: '🌳', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '湿地公园', emoji: '🦆', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '森林公园', emoji: '🌲', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '植物园', emoji: '🌻', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '动物园', emoji: '🐼', type: PlaceType.park, priceTier: 2),
      PlaceItem(name: '游乐园', emoji: '🎡', type: PlaceType.park, priceTier: 3),
      PlaceItem(name: '体育公园', emoji: '⚽', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '滨江步道', emoji: '🌉', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '山间步道', emoji: '⛰️', type: PlaceType.park, priceTier: 1),
      PlaceItem(name: '露营基地', emoji: '⛺', type: PlaceType.park, priceTier: 2),
      // 文化
      PlaceItem(name: '博物馆', emoji: '🏛️', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '美术馆', emoji: '🖼️', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '科技馆', emoji: '🔬', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '图书馆', emoji: '📖', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '电影院', emoji: '🎬', type: PlaceType.culture, priceTier: 2),
      PlaceItem(name: '剧院', emoji: '🎭', type: PlaceType.culture, priceTier: 3),
      PlaceItem(name: '音乐厅', emoji: '🎵', type: PlaceType.culture, priceTier: 3),
      PlaceItem(name: '天文馆', emoji: '🔭', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '历史古迹', emoji: '🏯', type: PlaceType.culture, priceTier: 1),
      PlaceItem(name: '文创园', emoji: '🎨', type: PlaceType.culture, priceTier: 1),
      // 运动
      PlaceItem(name: '健身房', emoji: '🏋️', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '游泳馆', emoji: '🏊', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '羽毛球馆', emoji: '🏸', type: PlaceType.sport, priceTier: 1),
      PlaceItem(name: '篮球场', emoji: '🏀', type: PlaceType.sport, priceTier: 1),
      PlaceItem(name: '滑冰场', emoji: '⛸️', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '攀岩馆', emoji: '🧗', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '射箭馆', emoji: '🏹', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '保龄球馆', emoji: '🎳', type: PlaceType.sport, priceTier: 2),
      PlaceItem(name: '台球厅', emoji: '🎱', type: PlaceType.sport, priceTier: 1),
      PlaceItem(name: '骑行绿道', emoji: '🚴', type: PlaceType.sport, priceTier: 1),
      // 夜生活
      PlaceItem(name: '酒吧', emoji: '🍸', type: PlaceType.night, priceTier: 3),
      PlaceItem(name: 'Livehouse', emoji: '🎸', type: PlaceType.night, priceTier: 2),
      PlaceItem(name: 'KTV', emoji: '🎤', type: PlaceType.night, priceTier: 2),
      PlaceItem(name: '深夜大排档', emoji: '🍳', type: PlaceType.night, priceTier: 1),
      PlaceItem(name: '夜市烧烤摊', emoji: '🍖', type: PlaceType.night, priceTier: 1),
    ];
  }
}
