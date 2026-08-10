/// 一条待办
class TodoItem {
  String title;
  String note;
  /// 计划日期（归一化到当天 00:00）
  DateTime date;
  bool done;
  String emoji;

  TodoItem({
    required this.title,
    required this.date,
    this.note = '',
    this.done = false,
    this.emoji = '📌',
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'note': note,
    'date': date.toIso8601String(),
    'done': done,
    'emoji': emoji,
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    title: json['title'] as String,
    note: json['note'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    done: json['done'] as bool? ?? false,
    emoji: json['emoji'] as String? ?? '📌',
  );
}
