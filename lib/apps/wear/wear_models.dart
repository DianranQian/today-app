import '../../core/season.dart';

/// 性别
enum WearGender { male, female, unisex }

extension WearGenderExt on WearGender {
  String get label {
    switch (this) {
      case WearGender.male: return '男';
      case WearGender.female: return '女';
      case WearGender.unisex: return '通用';
    }
  }

  static WearGender fromString(String s) {
    switch (s) {
      case 'male': return WearGender.male;
      case 'female': return WearGender.female;
      default: return WearGender.unisex;
    }
  }
}

/// 人群
enum WearGroup { student, office, elder, child, all }

extension WearGroupExt on WearGroup {
  String get label {
    switch (this) {
      case WearGroup.student: return '学生';
      case WearGroup.office: return '上班族';
      case WearGroup.elder: return '长辈';
      case WearGroup.child: return '儿童';
      case WearGroup.all: return '通用';
    }
  }

  static WearGroup fromString(String s) {
    switch (s) {
      case 'student': return WearGroup.student;
      case 'office': return WearGroup.office;
      case 'elder': return WearGroup.elder;
      case 'child': return WearGroup.child;
      default: return WearGroup.all;
    }
  }
}

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
  WearGender gender;
  WearGroup group;
  /// 适宜温度区间（摄氏度），null 表示不限
  int? tempMin;
  int? tempMax;
  String? imagePath;

  OutfitItem({
    required this.name,
    this.emoji = '👕',
    this.scene = WearScene.all,
    Set<Season>? seasons,
    this.gender = WearGender.unisex,
    this.group = WearGroup.all,
    this.tempMin,
    this.tempMax,
    this.imagePath,
  }) : seasons = seasons ?? {};

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'scene': scene.name,
    'seasons': seasons.map((s) => s.name).toList(),
    'gender': gender.name,
    'group': group.name,
    'tempMin': tempMin,
    'tempMax': tempMax,
    'imagePath': imagePath,
  };

  factory OutfitItem.fromJson(Map<String, dynamic> json) => OutfitItem(
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '👕',
    scene: WearSceneExt.fromString(json['scene'] as String? ?? 'all'),
    seasons: (json['seasons'] as List<dynamic>?)
        ?.map((e) => SeasonExt.fromString(e as String))
        .toSet() ?? {},
    gender: WearGenderExt.fromString(json['gender'] as String? ?? 'unisex'),
    group: WearGroupExt.fromString(json['group'] as String? ?? 'all'),
    tempMin: json['tempMin'] as int?,
    tempMax: json['tempMax'] as int?,
    imagePath: json['imagePath'] as String?,
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
