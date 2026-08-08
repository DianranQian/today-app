import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 计划类型（来源子应用）
enum PlanType { eat, go, wear, contact }

extension PlanTypeExt on PlanType {
  String get label {
    switch (this) {
      case PlanType.eat: return '吃';
      case PlanType.go: return '去';
      case PlanType.wear: return '穿';
      case PlanType.contact: return '联系';
    }
  }

  static PlanType fromString(String s) {
    switch (s) {
      case 'go': return PlanType.go;
      case 'wear': return PlanType.wear;
      case 'contact': return PlanType.contact;
      default: return PlanType.eat;
    }
  }
}

/// 一条计划（某天确认要做的事）
class PlanItem {
  /// 计划日期（归一化到当天 00:00）
  DateTime date;
  PlanType type;
  String title;
  String emoji;
  String note;

  PlanItem({
    required this.date,
    required this.type,
    required this.title,
    this.emoji = '📌',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'type': type.name,
    'title': title,
    'emoji': emoji,
    'note': note,
  };

  factory PlanItem.fromJson(Map<String, dynamic> json) => PlanItem(
    date: DateTime.parse(json['date'] as String),
    type: PlanTypeExt.fromString(json['type'] as String? ?? 'eat'),
    title: json['title'] as String,
    emoji: json['emoji'] as String? ?? '📌',
    note: json['note'] as String? ?? '',
  );
}

/// 计划清单存储
class PlanStore {
  static List<PlanItem> items = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('plan_items');
    if (raw != null && raw.isNotEmpty) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => PlanItem.fromJson(e as Map<String, dynamic>))
            .where((p) => p.title.isNotEmpty)
            .toList();
      } catch (_) {
        items = [];
      }
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('plan_items', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static void add(PlanItem item) {
    items.add(item);
    save();
  }

  static void remove(PlanItem item) {
    items.remove(item);
    save();
  }

  /// 按日期分组：返回 [日期, 条目列表]，日期降序
  static List<(DateTime, List<PlanItem>)> groupByDate() {
    final map = <DateTime, List<PlanItem>>{};
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      map.putIfAbsent(day, () => []).add(item);
    }
    final groups = map.entries
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => b.$1.compareTo(a.$1));
    return groups;
  }
}
