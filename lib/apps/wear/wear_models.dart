import '../../core/season.dart';

/// 穿搭场景
enum WearScene { daily, sport, formal, date, commute, all }

extension WearSceneExt on WearScene {
  String get label {
    switch (this) {
      case WearScene.daily: return '日常';
      case WearScene.sport: return '运动';
      case WearScene.formal: return '正式';
      case WearScene.date: return '约会';
      case WearScene.commute: return '通勤';
      case WearScene.all: return '全部';
    }
  }

  static WearScene fromString(String s) {
    switch (s) {
      case 'daily': return WearScene.daily;
      case 'sport': return WearScene.sport;
      case 'formal': return WearScene.formal;
      case 'date': return WearScene.date;
      case 'commute': return WearScene.commute;
      default: return WearScene.all;
    }
  }
}

/// 一套穿搭
class OutfitItem {
  String name;
  String emoji;
  WearScene scene;
  Set<Season> seasons;
  /// 适宜温度区间（摄氏度），null 表示不限
  int? tempMin;
  int? tempMax;

  OutfitItem({
    required this.name,
    this.emoji = '👕',
    this.scene = WearScene.all,
    Set<Season>? seasons,
    this.tempMin,
    this.tempMax,
  }) : seasons = seasons ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'scene': scene.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'tempMin': tempMin,
    'tempMax': tempMax,
  };

  factory OutfitItem.fromJson(Map<String, dynamic> json) => OutfitItem(
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '👕',
    scene: WearSceneExt.fromString(json['scene'] as String? ?? 'all'),
    seasons: (json['seasons'] as List<dynamic>?)
        ?.map((e) => SeasonExt.fromString(e as String))
        .toSet() ?? {},
    tempMin: json['tempMin'] as int?,
    tempMax: json['tempMax'] as int?,
  );
}

/// 穿搭历史记录
class WearHistoryRecord {
  final String outfitName;
  final String outfitEmoji;
  final DateTime date;

  WearHistoryRecord({
    required this.outfitName,
    required this.outfitEmoji,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'outfitName': outfitName,
    'outfitEmoji': outfitEmoji,
    'date': date.toIso8601String(),
  };

  factory WearHistoryRecord.fromJson(Map<String, dynamic> json) =>
      WearHistoryRecord(
        outfitName: json['outfitName'] as String,
        outfitEmoji: json['outfitEmoji'] as String? ?? '👕',
        date: DateTime.parse(json['date'] as String),
      );
}
