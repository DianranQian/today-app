import 'dart:convert';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/season.dart';
import '../models/food_item.dart';
import 'how_to_cook_dishes.dart';
import 'xiachufang_dishes.dart';

class ImportResult {
  int added = 0;
  int skipped = 0;
  final List<String> errors = [];

  bool get hasIssue => errors.isNotEmpty;

  @override
  String toString() {
    final sb = StringBuffer('导入完成：新增 $added 条');
    if (skipped > 0) sb.write('，跳过重复 $skipped 条');
    return sb.toString();
  }
}

class DataStore {
  static List<FoodItem> dishes = [];
  static List<FoodItem> staples = [];
  static List<FoodItem> drinks = [];
  static List<HistoryRecord> history = [];
  static AppSettings settings = AppSettings();

  /// 忌口/偏好排除词（命中食材则跳过推荐）
  static List<String> avoidIngredients = [];

  static const int dataVersion = 2;

  static String _sanitize(String s) {
    return s
        .replaceAll('\uFFFD', '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .trim();
  }

  /// 常用忌口词表（设置页多选用）
  static const avoidPresets = [
    '辣', '香菜', '葱', '蒜', '内脏', '海鲜', '鱼', '虾', '猪肉', '牛肉',
    '羊肉', '鸡蛋', '豆制品', '菌菇', '花生', '芝麻',
  ];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final dishesJson = prefs.getString('dishes');
    if (dishesJson != null && dishesJson.isNotEmpty) {
      final cleaned = _sanitize(dishesJson);
      if (cleaned.isEmpty) {
        dishes = getDefaultDishes();
      } else {
        try {
          final parsed = (jsonDecode(cleaned) as List)
              .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
              .where((d) => d.name.isNotEmpty)
              .toList();
          // 解析结果为空时回退默认库，避免空数组导致库永久为空
          dishes = parsed.isEmpty ? getDefaultDishes() : parsed;
        } catch (_) {
          dishes = getDefaultDishes();
        }
      }
    } else {
      dishes = getDefaultDishes();
    }
    saveNow(prefs);

    final staplesJson = prefs.getString('staples');
    if (staplesJson != null && staplesJson.isNotEmpty) {
      final cleaned = _sanitize(staplesJson);
      if (cleaned.isEmpty) {
        staples = getDefaultStaples();
      } else {
        try {
          final parsed = (jsonDecode(cleaned) as List)
              .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
              .where((s) => s.name.isNotEmpty)
              .toList();
          staples = parsed.isEmpty ? getDefaultStaples() : parsed;
        } catch (_) {
          staples = getDefaultStaples();
        }
      }
    } else {
      staples = getDefaultStaples();
    }

    final historyJson = prefs.getString('history');
    if (historyJson != null && historyJson.isNotEmpty) {
      final cleaned = _sanitize(historyJson);
      try {
        history = (jsonDecode(cleaned) as List)
            .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
            .where((h) => h.dishName.isNotEmpty)
            .toList();
      } catch (_) {
        history = [];
      }
    }

    final drinksJson = prefs.getString('drinks');
    if (drinksJson != null && drinksJson.isNotEmpty) {
      final cleaned = _sanitize(drinksJson);
      if (cleaned.isEmpty) {
        drinks = getDefaultDrinks();
      } else {
        try {
          final parsed = (jsonDecode(cleaned) as List)
              .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
              .where((d) => d.name.isNotEmpty)
              .toList();
          drinks = parsed.isEmpty ? getDefaultDrinks() : parsed;
        } catch (_) {
          drinks = getDefaultDrinks();
        }
      }
    } else {
      drinks = getDefaultDrinks();
    }

    final settingsJson = prefs.getString('settings');
    if (settingsJson != null && settingsJson.isNotEmpty) {
      try {
        settings = AppSettings.fromJson(jsonDecode(_sanitize(settingsJson)));
      } catch (_) {
        settings = AppSettings();
      }
    }

    // 忌口词表
    final avoidJson = prefs.getString('eat_avoid');
    if (avoidJson != null && avoidJson.isNotEmpty) {
      try {
        avoidIngredients =
            (jsonDecode(avoidJson) as List).cast<String>();
      } catch (_) {
        avoidIngredients = [];
      }
    }
  }

  static Future<void> saveNow([SharedPreferences? prefsInstance]) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    prefs.setString('dishes', jsonEncode(dishes.map((e) => e.toJson()).toList()));
    prefs.setString('staples', jsonEncode(staples.map((e) => e.toJson()).toList()));
    prefs.setString('drinks', jsonEncode(drinks.map((e) => e.toJson()).toList()));
    prefs.setString('history', jsonEncode(history.map((e) => e.toJson()).toList()));
    prefs.setString('settings', jsonEncode(settings.toJson()));
    prefs.setString('eat_avoid', jsonEncode(avoidIngredients));
  }

  static Future<void> save() => saveNow();

  static List<FoodItem> getFilteredDishes({
    MealTime? mealTime,
    CookMode? cookMode,
  }) {
    var result = List<FoodItem>.from(dishes);
    if (mealTime != null && mealTime != MealTime.all) {
      result = result.where((d) => d.mealTime == mealTime || d.mealTime == MealTime.all).toList();
    }
    if (cookMode != null && cookMode != CookMode.all) {
      result = result.where((d) => d.cookMode == cookMode || d.cookMode == CookMode.all).toList();
    }
    // 忌口过滤：原料命中忌口词的菜不推荐
    if (avoidIngredients.isNotEmpty) {
      result = result
          .where((d) => !d.ingredients
              .any((i) => avoidIngredients.any((a) => i.contains(a))))
          .toList();
    }
    return result;
  }

  static List<FoodItem> getFilteredStaples({MealTime? mealTime}) {
    var result = List<FoodItem>.from(staples);
    if (mealTime != null && mealTime != MealTime.all) {
      result = result.where((s) => s.mealTime == mealTime || s.mealTime == MealTime.all).toList();
    }
    return result;
  }

  static List<FoodItem> getFilteredDrinks({MealTime? mealTime}) {
    var result = List<FoodItem>.from(drinks);
    if (mealTime != null && mealTime != MealTime.all) {
      result = result.where((d) => d.mealTime == mealTime || d.mealTime == MealTime.all).toList();
    }
    return result;
  }

  static List<FoodItem> search(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(dishes);
    return dishes
        .where((d) =>
            d.name.toLowerCase().contains(kw) ||
            d.ingredients.any((i) => i.toLowerCase().contains(kw)))
        .toList();
  }

  static List<FoodItem> searchStaples(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(staples);
    return staples
        .where((s) =>
            s.name.toLowerCase().contains(kw) ||
            s.ingredients.any((i) => i.toLowerCase().contains(kw)))
        .toList();
  }

  static List<FoodItem> searchDrinks(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(drinks);
    return drinks
        .where((d) => d.name.toLowerCase().contains(kw))
        .toList();
  }

  static int _randomIndex(int length) =>
      DateTime.now().microsecondsSinceEpoch % length;

  /// seasonPriority 时按 [season] 过滤当季（默认当前真实季节）
  static FoodItem pickFrom(List<FoodItem> pool,
      {bool seasonPriority = false, Season? season}) {
    if (pool.isEmpty) {
      throw StateError('pool is empty');
    }
    var candidates = pool;
    if (seasonPriority) {
      final s = season ?? currentSeason;
      final inSeason =
          pool.where((d) => d.seasons.contains(s)).toList();
      if (inSeason.isNotEmpty && _randomIndex(100) < 80) {
        candidates = inSeason;
      }
    }
    return candidates[_randomIndex(candidates.length)];
  }

  static int mergeNewDefaults() {
    var added = 0;
    final existingNames = dishes.map((d) => d.name).toSet();
    for (final d in getDefaultDishes()) {
      if (!existingNames.contains(d.name)) {
        dishes.add(d);
        added++;
      }
    }
    final stapleNames = staples.map((s) => s.name).toSet();
    for (final s in getDefaultStaples()) {
      if (!stapleNames.contains(s.name)) {
        staples.add(s);
        added++;
      }
    }
    final drinkNames = drinks.map((d) => d.name).toSet();
    for (final d in getDefaultDrinks()) {
      if (!drinkNames.contains(d.name)) {
        drinks.add(d);
        added++;
      }
    }
    if (added > 0) save();
    return added;
  }

  /// 将文件字节解码为文本：优先 UTF-8（含 BOM 自动剥离），
  /// 出现乱码替换符则回退 GBK 解码，防止中文菜名乱码。
  static String decodeFileBytes(List<int> bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      bytes = bytes.sublist(3);
    }
    final utf8Text = utf8.decode(bytes, allowMalformed: true);
    if (!utf8Text.contains('\uFFFD')) return utf8Text;
    try {
      return gbk.decode(bytes);
    } catch (_) {
      return utf8Text;
    }
  }

  /// 从 JSON 文本导入菜谱。格式为数组，每个元素与 FoodItem JSON 一致；
  /// isStaple: true 的条目归入主食库。重名条目跳过，返回汇总结果。
  static ImportResult importRecipes(String jsonText) {
    final result = ImportResult();
    dynamic parsed;
    try {
      parsed = jsonDecode(jsonText);
    } catch (_) {
      result.errors.add('JSON 解析失败，请检查文件格式是否符合说明');
      return result;
    }
    final items = parsed is List ? parsed : [parsed];
    for (final item in items) {
      try {
        final food = FoodItem.fromJson(item as Map<String, dynamic>);
        if (food.name.isEmpty) {
          result.errors.add('存在空菜名条目，已跳过');
          continue;
        }
        if (food.isDrink) {
          if (drinks.any((d) => d.name == food.name)) {
            result.skipped++;
            continue;
          }
          drinks.add(food);
        } else if (food.isStaple) {
          if (staples.any((s) => s.name == food.name)) {
            result.skipped++;
            continue;
          }
          staples.add(food);
        } else {
          if (dishes.any((d) => d.name == food.name)) {
            result.skipped++;
            continue;
          }
          dishes.add(food);
        }
        result.added++;
      } catch (_) {
        result.errors.add('条目解析失败：${item.toString().length > 60 ? item.toString().substring(0, 60) : item}');
      }
    }
    if (result.added > 0) save();
    return result;
  }

  static Set<String> getRecentDishNames({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history
      .where((h) => h.date.isAfter(cutoff))
      .map((h) => h.dishName)
      .toSet();
  }

  static Set<String> getRecentStapleNames({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history
      .where((h) => h.date.isAfter(cutoff) && h.stapleName != null)
      .map((h) => h.stapleName!)
      .toSet();
  }

  static Set<String> getRecentDrinkNames({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return history
      .where((h) => h.date.isAfter(cutoff) && h.drinkName != null)
      .map((h) => h.drinkName!)
      .toSet();
  }

  static void addHistory(HistoryRecord record) {
    history.insert(0, record);
    if (history.length > 200) history = history.sublist(0, 200);
    save();
  }

  static void clearHistory() {
    history.clear();
    save();
  }

  static void resetToDefault() {
    dishes = getDefaultDishes();
    staples = getDefaultStaples();
    drinks = getDefaultDrinks();
    history.clear();
    settings = AppSettings();
    save();
  }

  static List<FoodItem> getDefaultDishes() {
    final merged = <FoodItem>[
      // 家常热菜·荤
      FoodItem(name: '番茄炒蛋', emoji: '🍅', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['番茄', '鸡蛋', '葱']),
      FoodItem(name: '宫保鸡丁', emoji: '🍗', mealTime: MealTime.lunch, cookMode: CookMode.all, ingredients: ['鸡胸肉', '花生', '干辣椒', '葱']),
      FoodItem(name: '鱼香肉丝', emoji: '🥢', mealTime: MealTime.lunch, cookMode: CookMode.all, ingredients: ['猪肉', '木耳', '胡萝卜', '青椒']),
      FoodItem(name: '红烧肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['五花肉', '冰糖', '酱油', '八角']),
      FoodItem(name: '回锅肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['五花肉', '青蒜', '豆瓣酱', '豆豉']),
      FoodItem(name: '青椒肉丝', emoji: '🫑', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['青椒', '猪肉', '蒜']),
      FoodItem(name: '糖醋里脊', emoji: '🥩', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['里脊肉', '糖', '醋', '淀粉']),
      FoodItem(name: '锅包肉', emoji: '🥩', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['里脊肉', '淀粉', '糖醋汁']),
      FoodItem(name: '可乐鸡翅', emoji: '🍗', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['鸡翅', '可乐', '姜']),
      FoodItem(name: '辣子鸡', emoji: '🍗', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['鸡腿', '干辣椒', '花椒', '花生']),
      FoodItem(name: '白切鸡', emoji: '🍗', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['三黄鸡', '姜', '葱']),
      FoodItem(name: '红烧排骨', emoji: '🍖', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['排骨', '冰糖', '酱油']),
      FoodItem(name: '板栗烧鸡', emoji: '🍗', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['鸡肉', '板栗', '姜']),
      FoodItem(name: '春笋炒肉', emoji: '🥢', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['春笋', '猪肉', '葱']),
      FoodItem(name: '小鸡炖蘑菇', emoji: '🍄', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['鸡肉', '榛蘑', '粉条', '葱姜']),
      FoodItem(name: '土豆炖牛肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['牛肉', '土豆', '胡萝卜']),
      FoodItem(name: '西红柿炖牛腩', emoji: '🍅', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['牛腩', '番茄', '洋葱']),
      FoodItem(name: '木须肉', emoji: '🥢', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['鸡蛋', '木耳', '黄瓜', '猪肉']),
      FoodItem(name: '京酱肉丝', emoji: '🥢', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['里脊肉', '甜面酱', '葱', '豆腐皮']),
      FoodItem(name: '鱼香茄子', emoji: '🍆', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['茄子', '豆瓣酱', '蒜', '肉末']),
      FoodItem(name: '蚂蚁上树', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['粉丝', '肉末', '豆瓣酱', '葱']),
      FoodItem(name: '麻婆豆腐', emoji: '🥘', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['嫩豆腐', '肉末', '豆瓣酱', '花椒']),
      FoodItem(name: '水煮鱼', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.winter}),
      FoodItem(name: '酸菜鱼', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['草鱼', '酸菜', '泡椒', '花椒']),
      FoodItem(name: '大闸蟹', emoji: '🦀', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.autumn}),
      FoodItem(name: '小龙虾', emoji: '🦞', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.summer}),
      FoodItem(name: '羊蝎子', emoji: '🍖', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.winter}),
      FoodItem(name: '火锅', emoji: '🫕', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.winter}),
      FoodItem(name: '羊肉汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['羊肉', '白萝卜', '香菜', '葱']),
      FoodItem(name: '羊肉泡馍', emoji: '🥙', mealTime: MealTime.lunch, cookMode: CookMode.eatOut, seasons: {Season.winter}),
      FoodItem(name: '白菜炖粉条', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['白菜', '粉条', '五花肉']),
      FoodItem(name: '韩式烤肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.eatOut),
      FoodItem(name: '烤串', emoji: '🍢', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.summer}),
      FoodItem(name: '牛排', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.eatOut),
      FoodItem(name: '天妇罗', emoji: '🍤', mealTime: MealTime.dinner, cookMode: CookMode.eatOut),
      FoodItem(name: '炸鸡', emoji: '🍗', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['鸡翅', '面粉', '面包糠']),
      FoodItem(name: '鸭脖', emoji: '🦆', mealTime: MealTime.all, cookMode: CookMode.takeout),
      FoodItem(name: '臭豆腐', emoji: '🧆', mealTime: MealTime.lunch, cookMode: CookMode.takeout),

      // 家常菜扩充·荤
      FoodItem(name: '红烧豆腐', emoji: '🍲', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['豆腐', '肉末', '葱']),
      FoodItem(name: '韭菜炒河虾', emoji: '🦐', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['韭菜', '小河虾']),
      FoodItem(name: '清蒸鲈鱼', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['鲈鱼', '姜', '葱', '蒸鱼豉油']),
      FoodItem(name: '红烧鱼块', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['草鱼', '葱姜蒜', '酱油']),
      FoodItem(name: '油焖大虾', emoji: '🦐', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['虾', '葱姜', '番茄酱']),
      FoodItem(name: '蒜蓉粉丝虾', emoji: '🍤', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['虾', '粉丝', '蒜']),
      FoodItem(name: '啤酒鸭', emoji: '🦆', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['鸭肉', '啤酒', '姜']),
      FoodItem(name: '香菇滑鸡', emoji: '🍄', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['鸡腿', '香菇', '姜']),
      FoodItem(name: '宫保虾仁', emoji: '🍤', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['虾仁', '花生', '干辣椒']),
      FoodItem(name: '孜然羊肉', emoji: '🍖', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['羊肉', '孜然', '洋葱']),
      FoodItem(name: '洋葱炒牛肉', emoji: '🧅', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['牛肉', '洋葱', '蚝油']),
      FoodItem(name: '芹菜炒牛肉', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['牛肉', '芹菜', '姜']),
      FoodItem(name: '蒜苔炒肉丝', emoji: '🥢', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['蒜苔', '猪肉', '姜']),
      FoodItem(name: '冬瓜烧肉', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['冬瓜', '五花肉']),

      // 家常菜扩充·素
      FoodItem(name: '干锅花菜', emoji: '🥦', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['花菜', '五花肉', '干辣椒']),
      FoodItem(name: '醋溜白菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['白菜', '醋', '干辣椒']),
      FoodItem(name: '蚝油生菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['生菜', '蚝油', '蒜']),
      FoodItem(name: '酸辣藕丁', emoji: '🥣', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['莲藕', '干辣椒', '醋']),
      FoodItem(name: '上汤娃娃菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['娃娃菜', '皮蛋', '火腿']),
      FoodItem(name: '干锅土豆片', emoji: '🥔', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['土豆', '干辣椒', '五花肉']),
      FoodItem(name: '拔丝地瓜', emoji: '🍠', mealTime: MealTime.all, cookMode: CookMode.eatOut, seasons: {Season.winter}, ingredients: ['红薯', '糖']),
      FoodItem(name: '韭菜炒豆芽', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['韭菜', '豆芽']),
      FoodItem(name: '尖椒炒蛋', emoji: '🫑', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['尖椒', '鸡蛋']),
      FoodItem(name: '荷兰豆炒腊肠', emoji: '🫛', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['荷兰豆', '腊肠', '蒜']),
      FoodItem(name: '南瓜饼', emoji: '🥞', mealTime: MealTime.all, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['南瓜', '糯米粉']),
      FoodItem(name: '玉米烙', emoji: '🌽', mealTime: MealTime.all, cookMode: CookMode.cook, ingredients: ['玉米', '淀粉']),
      FoodItem(name: '香煎藕饼', emoji: '🥞', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['莲藕', '肉末', '面粉']),
      FoodItem(name: '萝卜丝饼', emoji: '🫓', mealTime: MealTime.breakfast, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['白萝卜', '面粉', '鸡蛋']),
      FoodItem(name: '红糖糍粑', emoji: '🍡', mealTime: MealTime.all, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['糯米', '红糖']),

      // 家常菜扩充·汤
      FoodItem(name: '玉米排骨汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['玉米', '排骨']),
      FoodItem(name: '山药排骨汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['山药', '排骨']),
      FoodItem(name: '冬瓜丸子汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['冬瓜', '肉末']),
      FoodItem(name: '丝瓜蛋汤', emoji: '🥒', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['丝瓜', '鸡蛋']),
      FoodItem(name: '白萝卜鲫鱼汤', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['鲫鱼', '白萝卜', '姜']),

      // 家常菜扩充·面点
      FoodItem(name: '西红柿鸡蛋面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['面条', '番茄', '鸡蛋']),
      FoodItem(name: '葱油拌面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['面条', '葱', '酱油']),
      FoodItem(name: '酸汤水饺', emoji: '🥟', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['饺子', '番茄', '醋']),
      FoodItem(name: '泡菜炒饭', emoji: '🍚', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['米饭', '泡菜', '鸡蛋']),
      FoodItem(name: '肉末粥', emoji: '🥣', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['大米', '肉末', '姜']),
      FoodItem(name: '拔丝苹果', emoji: '🍎', mealTime: MealTime.all, cookMode: CookMode.eatOut, seasons: {Season.winter}, ingredients: ['苹果', '糖']),

      // 网抓家常菜（来源：下厨房家常菜分类）
      FoodItem(name: '炒合菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['豆芽', '胡萝卜', '韭菜', '粉丝', '鸡蛋']),
      FoodItem(name: '包菜炒粉丝', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['包菜', '粉丝', '肉丝', '鸡蛋']),
      FoodItem(name: '肉末西葫芦', emoji: '🥒', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['西葫芦', '肉末', '鸡蛋', '蒜']),
      FoodItem(name: '糖醋荷包蛋', emoji: '🥚', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['鸡蛋', '番茄酱', '糖', '醋']),
      FoodItem(name: '红烧日本豆腐', emoji: '🍮', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['日本豆腐', '胡萝卜', '青椒', '蒜']),
      FoodItem(name: '葱油焖鸡', emoji: '🍗', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['鸡腿', '生抽', '老抽', '蚝油', '葱', '姜']),
      FoodItem(name: '番茄炒豆腐', emoji: '🍅', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['豆腐', '番茄', '葱']),
      FoodItem(name: '糖醋茄子', emoji: '🍆', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['茄子', '糖', '醋', '淀粉', '蒜']),
      FoodItem(name: '干锅鸡翅虾', emoji: '🍤', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['虾', '鸡翅', '土豆', '洋葱', '蒜']),
      FoodItem(name: '叉烧肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['五花肉', '叉烧酱', '蜂蜜']),
      FoodItem(name: '香辣虾', emoji: '🦐', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['基围虾', '洋葱', '豆瓣酱', '干辣椒', '蒜']),
      FoodItem(name: '酸辣藕片', emoji: '🥣', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['莲藕', '干辣椒', '花椒', '醋']),
      FoodItem(name: '豉油鸡腿', emoji: '🍗', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['鸡腿', '生抽', '老抽', '蚝油', '洋葱', '姜', '八角']),
      FoodItem(name: '番茄牛肉汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['牛肉', '番茄', '姜', '葱']),
      FoodItem(name: '沙葱炒牛肉', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['牛肉', '沙葱', '小米椒']),
      FoodItem(name: '素炒娃娃菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['娃娃菜', '蒜', '干辣椒']),
      FoodItem(name: '辣炒凤爪', emoji: '🐔', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['凤爪', '青红辣椒', '黄豆酱', '蒜', '姜']),
      FoodItem(name: '肉沫土豆', emoji: '🥔', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['土豆', '猪肉末', '洋葱', '蒜']),
      FoodItem(name: '玉米火腿丁', emoji: '🌽', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['玉米', '火腿', '番茄', '黄瓜']),
      FoodItem(name: '香辣花甲', emoji: '🐚', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['花甲', '豆瓣酱', '小米辣', '姜', '蒜']),
      FoodItem(name: '糖醋带鱼', emoji: '🐟', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['带鱼', '料酒', '生抽', '醋', '糖']),
      FoodItem(name: '沙葱炒鸡蛋', emoji: '🥚', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['沙葱', '鸡蛋']),
      FoodItem(name: '青椒炒毛豆', emoji: '🫛', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['毛豆', '青椒', '蒜']),
      FoodItem(name: '韭菜花炒虾米', emoji: '🦐', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['韭菜花', '干虾米', '蒜', '干辣椒']),
      FoodItem(name: '素炒豆芽', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['豆芽', '火腿肠', '青椒', '蒜']),
      FoodItem(name: '江西辣牛腩', emoji: '🥩', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['牛腩', '干辣椒', '啤酒', '姜', '八角']),
      FoodItem(name: '河南大烩菜', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['五花肉', '粉条', '白菜', '木耳', '豆腐']),
      FoodItem(name: '蒜蓉粉丝生蚝', emoji: '🦪', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['生蚝', '粉丝', '蒜', '小米辣']),
      FoodItem(name: '腐竹炒肉片', emoji: '🥢', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['腐竹', '瘦肉', '青椒', '蒜苗']),
      FoodItem(name: '水煮肉片', emoji: '🥘', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['猪里脊', '豆芽', '油菜', '豆瓣酱', '干辣椒']),

      // 家常热菜·素
      FoodItem(name: '酸辣土豆丝', emoji: '🥔', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['土豆', '干辣椒', '醋']),
      FoodItem(name: '地三鲜', emoji: '🍆', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['茄子', '土豆', '青椒']),
      FoodItem(name: '手撕包菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['包菜', '干辣椒', '蒜']),
      FoodItem(name: '干煸豆角', emoji: '🫘', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['豆角', '干辣椒', '花椒', '肉末']),
      FoodItem(name: '虎皮青椒', emoji: '🫑', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['青椒', '蒜', '酱油']),
      FoodItem(name: '香菇油菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['香菇', '油菜', '蒜']),
      FoodItem(name: '蒜蓉西兰花', emoji: '🥦', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['西兰花', '蒜']),
      FoodItem(name: '清炒油麦菜', emoji: '🥬', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['油麦菜', '蒜']),
      FoodItem(name: '韭菜炒蛋', emoji: '🥚', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['韭菜', '鸡蛋']),
      FoodItem(name: '苦瓜炒蛋', emoji: '🥒', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['苦瓜', '鸡蛋']),
      FoodItem(name: '西红柿炒西葫芦', emoji: '🍅', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['番茄', '西葫芦']),
      FoodItem(name: '拍黄瓜', emoji: '🥒', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['黄瓜', '蒜', '醋']),
      FoodItem(name: '凉拌木耳', emoji: '🍄', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['木耳', '蒜', '香菜']),
      FoodItem(name: '凉拌藕片', emoji: '🥣', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['莲藕', '辣椒油', '蒜']),
      FoodItem(name: '葱油蚕豆', emoji: '🫛', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['蚕豆', '葱', '油']),
      FoodItem(name: '马兰头拌香干', emoji: '🥗', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['马兰头', '香干', '麻油']),
      FoodItem(name: '芦笋炒虾仁', emoji: '🍤', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['芦笋', '虾仁', '蒜']),

      // 汤羹
      FoodItem(name: '紫菜蛋花汤', emoji: '🥣', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['紫菜', '鸡蛋', '虾皮']),
      FoodItem(name: '番茄蛋汤', emoji: '🍅', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['番茄', '鸡蛋']),
      FoodItem(name: '冬瓜排骨汤', emoji: '🦴', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['冬瓜', '排骨']),
      FoodItem(name: '莲藕排骨汤', emoji: '🦴', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['莲藕', '排骨']),
      FoodItem(name: '酸辣汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['豆腐', '木耳', '鸡蛋', '胡椒']),
      FoodItem(name: '海带豆腐汤', emoji: '🍲', mealTime: MealTime.dinner, cookMode: CookMode.cook, ingredients: ['海带', '豆腐']),
      FoodItem(name: '砂锅粥', emoji: '🥣', mealTime: MealTime.dinner, cookMode: CookMode.eatOut, seasons: {Season.winter}),

      // 主食·面点
      FoodItem(name: '兰州拉面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '黄焖鸡米饭', emoji: '🍲', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '重庆小面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['面条', '辣椒油', '豌豆', '花生']),
      FoodItem(name: '热干面', emoji: '🍜', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['碱水面', '芝麻酱', '萝卜干']),
      FoodItem(name: '阳春面', emoji: '🍜', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['面条', '葱花', '猪油']),
      FoodItem(name: '油泼面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['面条', '辣椒面', '蒜', '青菜']),
      FoodItem(name: '麻酱凉面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['面条', '芝麻酱', '黄瓜']),
      FoodItem(name: '冷面', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.summer}),
      FoodItem(name: '螺蛳粉', emoji: '🍝', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.winter}),
      FoodItem(name: '桂林米粉', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '炒河粉', emoji: '🍜', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['河粉', '豆芽', '牛肉']),
      FoodItem(name: '炒饭', emoji: '🍚', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['米饭', '鸡蛋', '葱花']),
      FoodItem(name: '手抓饭', emoji: '🍚', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['大米', '羊肉', '胡萝卜']),
      FoodItem(name: '紫米饭团', emoji: '🍙', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['紫米', '肉松', '黄瓜']),
      FoodItem(name: '疙瘩汤', emoji: '🥣', mealTime: MealTime.breakfast, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['面粉', '番茄', '鸡蛋']),
      FoodItem(name: '饺子', emoji: '🥟', mealTime: MealTime.all, cookMode: CookMode.all, seasons: {Season.winter}, ingredients: ['面粉', '猪肉馅', '韭菜']),
      FoodItem(name: '包子', emoji: '🥟', mealTime: MealTime.breakfast, cookMode: CookMode.all, ingredients: ['面粉', '猪肉馅', '酵母']),
      FoodItem(name: '馄饨', emoji: '🥟', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['馄饨皮', '猪肉馅', '虾皮', '紫菜']),
      FoodItem(name: '荠菜馄饨', emoji: '🥟', mealTime: MealTime.breakfast, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['馄饨皮', '荠菜', '猪肉馅']),
      FoodItem(name: '韭菜盒子', emoji: '🥟', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['面粉', '韭菜', '鸡蛋']),
      FoodItem(name: '春饼', emoji: '🌯', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.spring}, ingredients: ['面粉', '京酱肉丝', '葱丝']),
      FoodItem(name: '烙饼', emoji: '🫓', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['面粉', '葱', '油']),
      FoodItem(name: '馅饼', emoji: '🫓', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['面粉', '猪肉馅', '韭菜']),
      FoodItem(name: '葱油饼', emoji: '🥞', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['面粉', '葱', '油']),
      FoodItem(name: '鸡蛋灌饼', emoji: '🥞', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['面粉', '鸡蛋', '生菜']),
      FoodItem(name: '煎饼果子', emoji: '🥞', mealTime: MealTime.breakfast, cookMode: CookMode.takeout),
      FoodItem(name: '烤冷面', emoji: '🫓', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '煲仔饭', emoji: '🍚', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.winter}),
      FoodItem(name: '石锅拌饭', emoji: '🍚', mealTime: MealTime.lunch, cookMode: CookMode.eatOut, seasons: {Season.winter}),
      FoodItem(name: '泡菜锅', emoji: '🥘', mealTime: MealTime.dinner, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['泡菜', '豆腐', '五花肉', '葱']),
      FoodItem(name: '咖喱饭', emoji: '🍛', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['咖喱块', '土豆', '胡萝卜', '洋葱']),

      // 早餐·粥点
      FoodItem(name: '皮蛋瘦肉粥', emoji: '🥣', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['大米', '皮蛋', '瘦肉', '姜']),
      FoodItem(name: '豆浆油条', emoji: '🥛', mealTime: MealTime.breakfast, cookMode: CookMode.takeout),
      FoodItem(name: '小笼包', emoji: '🥟', mealTime: MealTime.breakfast, cookMode: CookMode.takeout),
      FoodItem(name: '茶叶蛋', emoji: '🥚', mealTime: MealTime.breakfast, cookMode: CookMode.all, ingredients: ['鸡蛋', '茶叶', '酱油', '八角']),
      FoodItem(name: '豆腐脑', emoji: '🥣', mealTime: MealTime.breakfast, cookMode: CookMode.takeout),
      FoodItem(name: '酒酿圆子', emoji: '🍡', mealTime: MealTime.breakfast, cookMode: CookMode.cook, seasons: {Season.winter}, ingredients: ['糯米粉', '酒酿', '鸡蛋']),
      FoodItem(name: '三明治', emoji: '🥪', mealTime: MealTime.breakfast, cookMode: CookMode.cook, ingredients: ['面包', '火腿', '生菜', '芝士']),

      // 凉菜·夏季限定
      FoodItem(name: '凉皮', emoji: '🥣', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.summer}),
      FoodItem(name: '沙拉', emoji: '🥗', mealTime: MealTime.lunch, cookMode: CookMode.cook, seasons: {Season.summer}, ingredients: ['生菜', '番茄', '沙拉酱']),

      // 外卖·快餐
      FoodItem(name: '沙县小吃', emoji: '🥟', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '麻辣烫', emoji: '🌶️', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.winter}),
      FoodItem(name: '关东煮', emoji: '🍢', mealTime: MealTime.all, cookMode: CookMode.takeout, seasons: {Season.winter}),
      FoodItem(name: '汉堡', emoji: '🍔', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '披萨', emoji: '🍕', mealTime: MealTime.lunch, cookMode: CookMode.takeout),
      FoodItem(name: '寿司', emoji: '🍣', mealTime: MealTime.lunch, cookMode: CookMode.takeout, seasons: {Season.summer}),
      FoodItem(name: '意面', emoji: '🍝', mealTime: MealTime.lunch, cookMode: CookMode.cook, ingredients: ['意面', '番茄酱', '洋葱']),
      FoodItem(name: '烤红薯', emoji: '🍠', mealTime: MealTime.all, cookMode: CookMode.takeout, seasons: {Season.winter}),
      FoodItem(name: '糖炒栗子', emoji: '🌰', mealTime: MealTime.all, cookMode: CookMode.takeout, seasons: {Season.autumn}),
      FoodItem(name: '桂花糯米藕', emoji: '🍬', mealTime: MealTime.all, cookMode: CookMode.cook, seasons: {Season.autumn}, ingredients: ['莲藕', '糯米', '桂花糖']),

      // 开源项目 HowToCook 解析导入的菜谱（按菜名去重）
      ...getHowToCookDishes(),
      // 下厨房抓取的菜谱（按菜名去重）
      ...getXiachufangDishes(),
    ];
    final seen = <String>{};
    return merged.where((d) => seen.add(d.name)).toList();
  }

  static List<FoodItem> getDefaultStaples() {
    return [
      FoodItem(name: '白米饭', emoji: '🍚', mealTime: MealTime.all, isStaple: true, ingredients: ['大米']),
      FoodItem(name: '小米粥', emoji: '🥣', mealTime: MealTime.breakfast, isStaple: true, ingredients: ['小米']),
      FoodItem(name: '绿豆粥', emoji: '🥣', mealTime: MealTime.breakfast, isStaple: true, seasons: {Season.summer}, ingredients: ['绿豆', '大米']),
      FoodItem(name: '南瓜粥', emoji: '🥣', mealTime: MealTime.breakfast, isStaple: true, seasons: {Season.autumn}, ingredients: ['南瓜', '大米']),
      FoodItem(name: '面条', emoji: '🍜', mealTime: MealTime.lunch, isStaple: true, ingredients: ['面条', '青菜']),
      FoodItem(name: '馒头', emoji: '🥟', mealTime: MealTime.all, isStaple: true, ingredients: ['面粉', '酵母']),
      FoodItem(name: '全麦面包', emoji: '🍞', mealTime: MealTime.breakfast, isStaple: true),
      FoodItem(name: '红薯', emoji: '🍠', mealTime: MealTime.breakfast, isStaple: true, ingredients: ['红薯']),
      FoodItem(name: '燕麦粥', emoji: '🥣', mealTime: MealTime.breakfast, isStaple: true, ingredients: ['燕麦', '牛奶']),
      FoodItem(name: '玉米', emoji: '🌽', mealTime: MealTime.breakfast, isStaple: true, ingredients: ['玉米']),
    ];
  }

  static List<FoodItem> getDefaultDrinks() {
    return [
      // 奶茶/茶饮
      FoodItem(name: '奶茶', emoji: '🧋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '珍珠奶茶', emoji: '🧋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '芋圆奶茶', emoji: '🧋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '烧仙草', emoji: '🍮', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冰粉', emoji: '🍧', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '双皮奶', emoji: '🍮', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冰糖雪梨', emoji: '🍐', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '龟苓膏', emoji: '🍮', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '柠檬茶', emoji: '🍋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '金桔柠檬', emoji: '🍊', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '百香果茶', emoji: '🫧', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '杨枝甘露', emoji: '🧋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冰红茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冰绿茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '抹茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '乌龙茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '绿茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '红茶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '花茶', emoji: '🌺', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '蜂蜜柚子茶', emoji: '🍯', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '凉茶', emoji: '🫖', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '东方树叶', emoji: '🍵', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '茶π', emoji: '🧋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '王老吉', emoji: '🫙', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '加多宝', emoji: '🫙', mealTime: MealTime.all, isDrink: true),
      // 咖啡
      FoodItem(name: '咖啡', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冰美式', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '拿铁', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '卡布奇诺', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '摩卡', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '冷萃咖啡', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '气泡美式', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '星冰乐', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '热巧克力', emoji: '☕', mealTime: MealTime.all, isDrink: true),
      // 汽水/果汁/乳饮
      FoodItem(name: '可乐', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '雪碧', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '芬达', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '美年达', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '七喜', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '北冰洋', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '健力宝', emoji: '🥤', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '气泡水', emoji: '🫧', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '苏打水', emoji: '🫧', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '元气森林', emoji: '🫧', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '果汁', emoji: '🧃', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '橙汁', emoji: '🍊', mealTime: MealTime.breakfast, isDrink: true),
      FoodItem(name: '苹果汁', emoji: '🍎', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '西瓜汁', emoji: '🍉', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '甘蔗汁', emoji: '🧃', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '椰子水', emoji: '🥥', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '果粒橙', emoji: '🍊', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '椰汁', emoji: '🥥', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '杏仁露', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '核桃露', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '花生牛奶', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '维他奶', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '旺仔牛奶', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: 'AD钙奶', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '营养快线', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '养乐多', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '乳酸菌饮料', emoji: '🥛', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '豆浆', emoji: '🥛', mealTime: MealTime.breakfast, isDrink: true),
      FoodItem(name: '牛奶', emoji: '🥛', mealTime: MealTime.breakfast, isDrink: true),
      FoodItem(name: '酸奶', emoji: '🥛', mealTime: MealTime.breakfast, isDrink: true),
      FoodItem(name: '豆奶', emoji: '🥛', mealTime: MealTime.breakfast, isDrink: true),
      // 能量/功能饮品
      FoodItem(name: '红牛', emoji: '🥫', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '脉动', emoji: '🫙', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '宝矿力水特', emoji: '🫙', mealTime: MealTime.all, isDrink: true),
      // 中式传统
      FoodItem(name: '酸梅汤', emoji: '🫙', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '绿豆汤', emoji: '🫘', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '银耳汤', emoji: '🥣', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '红豆沙', emoji: '🥣', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '柠檬水', emoji: '🍋', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '姜茶', emoji: '🫚', mealTime: MealTime.all, isDrink: true),
      FoodItem(name: '热水', emoji: '🫖', mealTime: MealTime.all, isDrink: true),
    ];
  }
}
