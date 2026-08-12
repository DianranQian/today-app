import 'package:flutter/material.dart';
import '../language.dart';
import '../scheme_store.dart';

/// 「参与随机的方案」多选（设置界面用）
class SchemeRandomPoolPicker extends StatefulWidget {
  const SchemeRandomPoolPicker({super.key, required this.appId});

  final String appId;

  @override
  State<SchemeRandomPoolPicker> createState() => _SchemeRandomPoolPickerState();
}

class _SchemeRandomPoolPickerState extends State<SchemeRandomPoolPicker> {
  List<String> _schemes = [];
  List<String> _pool = [];

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (SchemeStore.notifier.value == widget.appId) _load();
  }

  Future<void> _load() async {
    final schemes = await SchemeStore.list(widget.appId);
    final pool = await SchemeStore.randomPool(widget.appId);
    if (!mounted) return;
    setState(() {
      _schemes = schemes;
      _pool = pool;
    });
  }

  Future<void> _toggle(String name, bool checked) async {
    final next = List<String>.from(_pool);
    if (checked) {
      if (!next.contains(name)) next.add(name);
    } else {
      next.remove(name);
    }
    if (next.isEmpty) next.add(name); // 至少保留一个方案参与随机
    setState(() => _pool = next);
    await SchemeStore.setRandomPool(widget.appId, next);
  }

  @override
  Widget build(BuildContext context) {
    if (_schemes.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.casino, color: Colors.orange),
            title: Text(t('参与随机的方案', 'Schemes in random pool'),
                style: const TextStyle(fontSize: 14)),
            subtitle: Text(t('勾选的方案会一起参与随机抽取（按名称去重）',
                'Checked schemes are pooled for random picks (deduped by name)'),
                style: const TextStyle(fontSize: 11)),
          ),
          for (final name in _schemes)
            CheckboxListTile(
              dense: true,
              value: _pool.contains(name),
              onChanged: (v) => _toggle(name, v ?? false),
              title: Text(name, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}
