/// 联系频率
enum ContactFrequency { weekly, monthly, quarterly }

extension ContactFrequencyExt on ContactFrequency {
  String get label {
    switch (this) {
      case ContactFrequency.weekly: return '每周';
      case ContactFrequency.monthly: return '每月';
      case ContactFrequency.quarterly: return '每季度';
    }
  }

  int get days {
    switch (this) {
      case ContactFrequency.weekly: return 7;
      case ContactFrequency.monthly: return 30;
      case ContactFrequency.quarterly: return 90;
    }
  }

  static ContactFrequency fromString(String s) {
    switch (s) {
      case 'weekly': return ContactFrequency.weekly;
      case 'quarterly': return ContactFrequency.quarterly;
      default: return ContactFrequency.monthly;
    }
  }
}

/// 联系人（手动录入，不读系统通讯录）
class ContactItem {
  String name;
  String emoji;
  String relation;
  ContactFrequency frequency;
  DateTime? lastContact; // null = 从未联系过

  ContactItem({
    required this.name,
    this.emoji = '👤',
    this.relation = '',
    this.frequency = ContactFrequency.monthly,
    this.lastContact,
  });

  /// 距上次联系天数；从未联系返回很大的数（优先推荐）
  int get daysSinceContact {
    final last = lastContact;
    if (last == null) return 9999;
    return DateTime.now().difference(last).inDays;
  }

  /// 逾期天数（>0 表示该联系了）
  int get overdueDays => daysSinceContact - frequency.days;

  bool get isOverdue => overdueDays > 0;

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'relation': relation,
    'frequency': frequency.name,
    'lastContact': lastContact?.toIso8601String(),
  };

  factory ContactItem.fromJson(Map<String, dynamic> json) => ContactItem(
    name: json['name'] as String,
    emoji: json['emoji'] as String? ?? '👤',
    relation: json['relation'] as String? ?? '',
    frequency:
        ContactFrequencyExt.fromString(json['frequency'] as String? ?? 'monthly'),
    lastContact: json['lastContact'] != null
        ? DateTime.parse(json['lastContact'] as String)
        : null,
  );
}
