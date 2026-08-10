import 'package:flutter/material.dart';
import '../core/plan_store.dart';
import '../core/season.dart';

/// 计划清单页（主框架「计划」Tab）
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  String dayLabel(DateTime d) {
    final name = quickDayName(d);
    if (name != null) return '$name · ${formatMdCn(d)}';
    return '${formatMdCn(d)} · 周${weekdayCn(d.weekday)}';
  }

  @override
  Widget build(BuildContext context) {
    final groups = PlanStore.groupByDate();

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划清单'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📅', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text('还没有计划\n在子应用里选中后点「加入计划」',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          height: 1.5)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final (day, items) in groups) ...[
                  Text(dayLabel(day),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Text(item.emoji,
                            style: const TextStyle(fontSize: 26)),
                        title: Text(item.title),
                        subtitle: Text([
                          item.type.label,
                          if (item.note.isNotEmpty) item.note,
                        ].join(' · ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() => PlanStore.remove(item));
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}
