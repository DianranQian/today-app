import 'package:flutter/material.dart';
import 'go_models.dart';
import 'go_data_store.dart';

class GoManagePage extends StatefulWidget {
  const GoManagePage({super.key});

  @override
  State<GoManagePage> createState() => _GoManagePageState();
}

class _GoManagePageState extends State<GoManagePage> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  PlaceType _type = PlaceType.eat;
  int _priceTier = 1;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('请输入去处名称');
      return;
    }
    if (GoDataStore.places.any((p) => p.name == name)) {
      _showToast('这个去处已经存在了');
      return;
    }
    GoDataStore.places.add(PlaceItem(
      name: name,
      emoji: _emojiCtrl.text.trim().isNotEmpty ? _emojiCtrl.text.trim() : '📍',
      type: _type,
      priceTier: _priceTier,
    ));
    GoDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    setState(() {});
    _showToast('已添加 $name');
  }

  void _delete(int index) {
    final name = GoDataStore.places[index].name;
    GoDataStore.places.removeAt(index);
    GoDataStore.save();
    setState(() {});
    _showToast('已删除 $name');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = GoDataStore.search(_searchCtrl.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理去处'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('添加去处',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '去处名称',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _emojiCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Emoji',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          maxLength: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PlaceType>(
                          value: _type,
                          decoration: const InputDecoration(
                            labelText: '类型',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final t in PlaceType.values)
                              if (t != PlaceType.all)
                                DropdownMenuItem(
                                    value: t, child: Text(t.label)),
                          ],
                          onChanged: (v) => setState(() => _type = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _priceTier,
                          decoration: const InputDecoration(
                            labelText: '消费档位',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('¥ 低')),
                            DropdownMenuItem(value: 2, child: Text('¥¥ 中')),
                            DropdownMenuItem(value: 3, child: Text('¥¥¥ 高')),
                          ],
                          onChanged: (v) => setState(() => _priceTier = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('添加'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '按名称搜索',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (places.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('没有找到匹配的去处', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...places.asMap().entries.map((entry) {
              final i = GoDataStore.places.indexOf(entry.value);
              final place = entry.value;
              return Dismissible(
                key: ValueKey('place__${place.name}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _delete(i),
                child: ListTile(
                  leading: Text(place.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(place.name),
                  subtitle: Text('${place.type.label} · ${place.priceLabel}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(i),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          if (GoDataStore.history.isNotEmpty) ...[
            const Text('最近推荐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...GoDataStore.history.take(20).map((h) {
              final dateStr = '${h.date.month}/${h.date.day} '
                  '${h.date.hour.toString().padLeft(2, "0")}:${h.date.minute.toString().padLeft(2, "0")}';
              return ListTile(
                dense: true,
                leading: Text(h.placeEmoji, style: const TextStyle(fontSize: 22)),
                title: Text(h.placeName),
                subtitle: Text(dateStr),
              );
            }),
            TextButton(
              onPressed: () {
                GoDataStore.clearHistory();
                setState(() {});
                _showToast('历史已清空');
              },
              child: const Text('清空历史'),
            ),
          ],
        ],
      ),
    );
  }
}
