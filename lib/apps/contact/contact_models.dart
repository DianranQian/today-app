import '../../core/language.dart';

/// 联系频率
enum ContactFrequency { weekly, monthly, quarterly }

extension ContactFrequencyExt on ContactFrequency {
  String get label {
    switch (this) {
      case ContactFrequency.weekly: return t('每周');
      case ContactFrequency.monthly: return t('每月');
      case ContactFrequency.quarterly: return t('每季度');
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

/// 联系方式类型
enum ContactType { phone, wechat, email, qq, other }

extension ContactTypeExt on ContactType {
  String get label {
    switch (this) {
      case ContactType.phone: return t('手机');
      case ContactType.wechat: return t('微信');
      case ContactType.email: return t('邮箱');
      case ContactType.qq: return 'QQ';
      case ContactType.other: return t('其他');
    }
  }

  String get icon {
    switch (this) {
      case ContactType.phone: return '📱';
      case ContactType.wechat: return '💬';
      case ContactType.email: return '✉️';
      case ContactType.qq: return '🐧';
      case ContactType.other: return '🔗';
    }
  }

  static ContactType fromString(String s) {
    switch (s) {
      case 'phone': return ContactType.phone;
      case 'wechat': return ContactType.wechat;
      case 'email': return ContactType.email;
      case 'qq': return ContactType.qq;
      default: return ContactType.other;
    }
  }
}

/// 一条联系方式
class ContactMethod {
  final ContactType type;
  final String value;

  const ContactMethod({required this.type, required this.value});

  Map<String, dynamic> toJson() => {'type': type.name, 'value': value};

  factory ContactMethod.fromJson(Map<String, dynamic> json) => ContactMethod(
    type: ContactTypeExt.fromString(json['type'] as String? ?? 'other'),
    value: json['value'] as String? ?? '',
  );
}

/// 联系人（手动录入，不读系统通讯录）
class ContactItem {
  String name;
  String emoji;
  String relation;
  ContactFrequency frequency;
  DateTime? lastContact; // null = 从未联系过
  String? imagePath;
  List<ContactMethod> contacts;

  ContactItem({
    required this.name,
    this.emoji = '👤',
    this.relation = '',
    this.frequency = ContactFrequency.monthly,
    this.lastContact,
    this.imagePath,
    List<ContactMethod>? contacts,
  }) : contacts = contacts ?? [];

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
    'imagePath': imagePath,
    'contacts': contacts.map((c) => c.toJson()).toList(),
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
    imagePath: json['imagePath'] as String?,
    contacts: (json['contacts'] as List<dynamic>?)
        ?.map((e) => ContactMethod.fromJson(e as Map<String, dynamic>))
        .where((m) => m.value.isNotEmpty)
        .toList() ??
        [],
  );
}
