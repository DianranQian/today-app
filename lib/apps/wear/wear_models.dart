import '../../core/season.dart';
import '../../core/language.dart';

/// 性别
enum WearGender { male, female, unisex }

extension WearGenderExt on WearGender {
  String get label {
    switch (this) {
      case WearGender.male: return t('男', 'Male');
      case WearGender.female: return t('女', 'Female');
      case WearGender.unisex: return t('通用', 'Unisex');
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
      case WearGroup.student: return t('学生', 'Student');
      case WearGroup.office: return t('上班族', 'Office');
      case WearGroup.elder: return t('长辈', 'Senior');
      case WearGroup.child: return t('儿童', 'Child');
      case WearGroup.all: return t('通用', 'All');
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

/// 风格
enum WearStyle { casual, business, sweet, retro, trendy, all }

extension WearStyleExt on WearStyle {
  String get label {
    switch (this) {
      case WearStyle.casual: return t('休闲', 'Casual');
      case WearStyle.business: return t('商务', 'Business');
      case WearStyle.sweet: return t('甜美', 'Sweet');
      case WearStyle.retro: return t('复古', 'Retro');
      case WearStyle.trendy: return t('潮流', 'Trendy');
      case WearStyle.all: return t('通用', 'All');
    }
  }

  static WearStyle fromString(String s) {
    switch (s) {
      case 'casual': return WearStyle.casual;
      case 'business': return WearStyle.business;
      case 'sweet': return WearStyle.sweet;
      case 'retro': return WearStyle.retro;
      case 'trendy': return WearStyle.trendy;
      default: return WearStyle.all;
    }
  }
}

/// 穿搭场景
enum WearScene { daily, sport, formal, date, commute, all }

extension WearSceneExt on WearScene {
  String get label {
    switch (this) {
      case WearScene.daily: return t('日常', 'Daily');
      case WearScene.sport: return t('运动', 'Sports');
      case WearScene.formal: return t('正式', 'Formal');
      case WearScene.date: return t('约会', 'Date');
      case WearScene.commute: return t('通勤', 'Commute');
      case WearScene.all: return t('全部', 'All');
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
  WearStyle style;
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
    this.style = WearStyle.all,
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
    'style': style.name,
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
    style: WearStyleExt.fromString(json['style'] as String? ?? 'all'),
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
