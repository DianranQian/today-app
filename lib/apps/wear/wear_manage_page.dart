import 'package:flutter/material.dart';
import '../../core/season.dart';
import 'wear_models.dart';
import 'wear_data_store.dart';

class WearManagePage extends StatefulWidget {
  const WearManagePage({super.key});

  @override
  State<WearManagePage> createState() => _WearManagePageState();
}

class _WearManagePageState extends State<WearManagePage> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  WearScene _scene = WearScene.daily;
  int? _tempMin;
  int? _tempMax;

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
      _showToast('请输入穿搭名称');
      return;
    }
    if (WearDataStore.outfits.any((o) => o.name == name)) {
      _showToast('这套穿搭已经存在了');
      return;
    }
    WearDataStore.outfits.add(OutfitItem(
      name: name,
      emoji: _emojiCtrl.text.trim().isNotEmpty ? _emojiCtrl.text.trim() : '👕',
      scene: _scene,
      tempMin: _tempMin,
      tempMax: _tempMax,
    ));
    WearDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    setState(() {});
    _showToast('已添加 $name');
  }

  void _delete(int index) {
    final name = WearDataStore.outfits[index].name;
    WearDataStore.outfits.removeAt(index);
    WearDataStore.save();
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
    final outfits = WearDataStore.search(_searchCtrl.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理穿搭'),
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
                  const Text('添加穿搭',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '穿搭名称',
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
                        child: DropdownButtonFormField<WearScene>(
                          value: _scene,
                          decoration: const InputDecoration(
                            labelText: '场景',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final s in WearScene.values)
                              if (s != WearScene.all)
                                DropdownMenuItem(
                                    value: s, child: Text(s.label)),
                          ],
                          onChanged: (v) => setState(() => _scene = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _tempMin,
                          decoration: const InputDecoration(
                            labelText: '最低温',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('不限')),
                            for (var t = -10; t <= 30; t += 5)
                              DropdownMenuItem(value: t, child: Text('$t°C')),
                          ],
                          onChanged: (v) => setState(() => _tempMin = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          value: _tempMax,
                          decoration: const InputDecoration(
                            labelText: '最高温',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('不限')),
                            for (var t = 5; t <= 45; t += 5)
                              DropdownMenuItem(value: t, child: Text('$t°C')),
                          ],
                          onChanged: (v) => setState(() => _tempMax = v),
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
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
          if (outfits.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('没有找到匹配的穿搭', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...outfits.asMap().entries.map((entry) {
              final i = WearDataStore.outfits.indexOf(entry.value);
              final outfit = entry.value;
              final seasonTag = outfit.seasons.isEmpty
                  ? '四季通用'
                  : outfit.seasons.map((s) => s.label).join('/');
              return Dismissible(
                key: ValueKey('outfit__${outfit.name}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _delete(i),
                child: ListTile(
                  leading: Text(outfit.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(outfit.name),
                  subtitle: Text('${outfit.scene.label} · $seasonTag季'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(i),
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          if (WearDataStore.history.isNotEmpty) ...[
            const Text('最近推荐',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...WearDataStore.history.take(20).map((h) {
              final dateStr = '${h.date.month}/${h.date.day} '
                  '${h.date.hour.toString().padLeft(2, "0")}:${h.date.minute.toString().padLeft(2, "0")}';
              return ListTile(
                dense: true,
                leading: Text(h.outfitEmoji, style: const TextStyle(fontSize: 22)),
                title: Text(h.outfitName),
                subtitle: Text(dateStr),
              );
            }),
            TextButton(
              onPressed: () {
                WearDataStore.clearHistory();
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
