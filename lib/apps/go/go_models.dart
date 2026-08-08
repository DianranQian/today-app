/// 去处类型
enum PlaceType { eat, shop, park, culture, sport, night, all }

extension PlaceTypeExt on PlaceType {
  String get label {
    switch (this) {
      case PlaceType.eat: return '吃饭';
      case PlaceType.shop: return '逛街';
      case PlaceType.park: return '公园';
      case PlaceType.culture: return '文化';
      case PlaceType.sport: return '运动';
      case PlaceType.night: return '夜生活';
      case PlaceType.all: return '全部';
    }
  }

  static PlaceType fromString(String s) {
    switch (s) {
      case 'eat': return PlaceType.eat;
      case 'shop': return PlaceType.shop;
      case 'park': return PlaceType.park;
      case 'culture': return PlaceType.culture;
      case 'sport': return PlaceType.sport;
      case 'night': return PlaceType.night;
      default: return PlaceType.all;
    }
  }
}

/// 去处
class PlaceItem {
  String name;
  String emoji;
  PlaceType type;
  /// 消费档位：1 = 低（¥），2 = 中（¥¥），3 = 高（¥¥¥）
  int priceTier;

  PlaceItem({
    required this.name,
    this.emoji = '📍',
    this.type = PlaceType.all,
    this.priceTier = 1,
  });

  String get priceLabel => '¥' * priceTier;

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'type': type.name,
    'priceTier': priceTier,
  };

  factory PlaceItem.fromJson(Map<String, dynamic> json) => PlaceItem(
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '📍',
    type: PlaceTypeExt.fromString(json['type'] as String? ?? 'all'),
    priceTier: json['priceTier'] as int? ?? 1,
  );
}

/// 去处历史记录
class GoHistoryRecord {
  final String placeName;
  final String placeEmoji;
  final DateTime date;

  GoHistoryRecord({
    required this.placeName,
    required this.placeEmoji,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'placeName': placeName,
    'placeEmoji': placeEmoji,
    'date': date.toIso8601String(),
  };

  factory GoHistoryRecord.fromJson(Map<String, dynamic> json) => GoHistoryRecord(
    placeName: json['placeName'] as String,
    placeEmoji: json['placeEmoji'] as String? ?? '📍',
    date: DateTime.parse(json['date'] as String),
  );
}
