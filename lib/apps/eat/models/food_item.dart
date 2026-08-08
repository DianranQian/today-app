
import '../../../core/season.dart';

enum MealTime { breakfast, lunch, dinner, all }

enum CookMode { takeout, cook, eatOut, all }

extension MealTimeExt on MealTime {
  String get label {
    switch (this) {
      case MealTime.breakfast: return '早餐';
      case MealTime.lunch: return '午餐';
      case MealTime.dinner: return '晚餐';
      case MealTime.all: return '通用';
    }
  }
  
  static MealTime fromString(String s) {
    switch (s) {
      case 'breakfast': return MealTime.breakfast;
      case 'lunch': return MealTime.lunch;
      case 'dinner': return MealTime.dinner;
      default: return MealTime.all;
    }
  }
}

extension CookModeExt on CookMode {
  String get label {
    switch (this) {
      case CookMode.takeout: return '外卖';
      case CookMode.cook: return '自己做';
      case CookMode.eatOut: return '出去吃';
      case CookMode.all: return '不限方式';
    }
  }
  
  static CookMode fromString(String s) {
    switch (s) {
      case 'takeout': return CookMode.takeout;
      case 'cook': return CookMode.cook;
      case 'eatOut': return CookMode.eatOut;
      default: return CookMode.all;
    }
  }
}

class FoodItem {
  String name;
  String emoji;
  MealTime mealTime;
  CookMode cookMode;
  bool isStaple;
  bool isDrink;
  List<String> ingredients;
  Set<Season> seasons;
  String? imagePath;

  String get displayEmoji => emoji.trim().isEmpty ? '🍽️' : emoji;

  FoodItem({
    required this.name,
    this.emoji = '🍽️',
    this.mealTime = MealTime.all,
    this.cookMode = CookMode.all,
    this.isStaple = false,
    this.isDrink = false,
    List<String>? ingredients,
    Set<Season>? seasons,
    this.imagePath,
  })  : ingredients = ingredients ?? [],
        seasons = seasons ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'mealTime': mealTime.name,
    'cookMode': cookMode.name,
    'isStaple': isStaple,
    'isDrink': isDrink,
    'ingredients': ingredients,
    'seasons': seasons.map((s) => s.name).toList(),
    'imagePath': imagePath,
  };

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '🍽️',
    mealTime: MealTimeExt.fromString(json['mealTime'] as String? ?? 'all'),
    cookMode: CookModeExt.fromString(json['cookMode'] as String? ?? 'all'),
    isStaple: json['isStaple'] as bool? ?? false,
    isDrink: json['isDrink'] as bool? ?? false,
    ingredients: (json['ingredients'] as List<dynamic>?)?.cast<String>() ?? [],
    seasons: (json['seasons'] as List<dynamic>?)
        ?.map((e) => SeasonExt.fromString(e as String))
        .toSet() ?? {},
    imagePath: json['imagePath'] as String?,
  );
}

class HistoryRecord {
  final String dishName;
  final String? stapleName;
  final String? drinkName;
  final String dishEmoji;
  final String? stapleEmoji;
  final String? drinkEmoji;
  final DateTime date;
  final MealTime mealTime;
  final CookMode cookMode;

  HistoryRecord({
    required this.dishName,
    this.stapleName,
    this.drinkName,
    required this.dishEmoji,
    this.stapleEmoji,
    this.drinkEmoji,
    required this.date,
    required this.mealTime,
    required this.cookMode,
  });

  Map<String, dynamic> toJson() => {
    'dishName': dishName,
    'stapleName': stapleName,
    'drinkName': drinkName,
    'dishEmoji': dishEmoji,
    'stapleEmoji': stapleEmoji,
    'drinkEmoji': drinkEmoji,
    'date': date.toIso8601String(),
    'mealTime': mealTime.name,
    'cookMode': cookMode.name,
  };

  factory HistoryRecord.fromJson(Map<String, dynamic> json) => HistoryRecord(
    dishName: json['dishName'] as String,
    stapleName: json['stapleName'] as String?,
    drinkName: json['drinkName'] as String?,
    dishEmoji: json['dishEmoji'] as String? ?? '🍽️',
    stapleEmoji: json['stapleEmoji'] as String?,
    drinkEmoji: json['drinkEmoji'] as String?,
    date: DateTime.parse(json['date'] as String),
    mealTime: MealTimeExt.fromString(json['mealTime'] as String? ?? 'all'),
    cookMode: CookModeExt.fromString(json['cookMode'] as String? ?? 'all'),
  );
}

class AppSettings {
  bool noRepeat;
  bool avoidRecent;
  bool seasonRecommend;
  String amapKey;
  String deepseekKey;

  AppSettings({
    this.noRepeat = true,
    this.avoidRecent = true,
    this.seasonRecommend = true,
    this.amapKey = '',
    this.deepseekKey = '',
  });

  Map<String, dynamic> toJson() => {
    'noRepeat': noRepeat,
    'avoidRecent': avoidRecent,
    'seasonRecommend': seasonRecommend,
    'amapKey': amapKey,
    'deepseekKey': deepseekKey,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    noRepeat: json['noRepeat'] as bool? ?? true,
    avoidRecent: json['avoidRecent'] as bool? ?? true,
    seasonRecommend: json['seasonRecommend'] as bool? ?? true,
    amapKey: json['amapKey'] as String? ?? '',
    deepseekKey: json['deepseekKey'] as String? ?? '',
  );
}
