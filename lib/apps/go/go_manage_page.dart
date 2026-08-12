import 'package:flutter/material.dart';
import '../../core/image_helper.dart';
import 'dart:convert';
import '../../core/profile_store.dart';
import '../../core/services/ai_service.dart';
import '../../core/widgets/profile_dialog.dart';
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
  String? _imagePath;

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
      imagePath: _imagePath,
    ));
    GoDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    _imagePath = null;
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


  Future<void> _pickImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _imagePath = p);
  }

  Widget _buildImagePickerRow() {
    return Row(
      children: [
        ItemImage(imagePath: _imagePath, emoji: '📍', size: 48),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('添加图片'),
          ),
        ),
        if (_imagePath != null)
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => setState(() => _imagePath = null),
          ),
      ],
    );
  }

  /// 配置集：另存为 / 应用 / 导出 / AI 汇总
  Future<void> _openProfiles() async {
    await showProfileDialog(
      context,
      appId: 'go',
      currentItems: GoDataStore.places.map((p) => p.toJson()).toList(),
      applyItems: (items) {
        setState(() {
          GoDataStore.places = items.map((e) => PlaceItem.fromJson(e)).toList();
          GoDataStore.save();
        });
      },
      aiCurate: _aiCurateGo,
      exportBaseName: 'go_places',
    );
  }

  /// AI 汇总：挑选一组适合周末的去处，存为「AI精选」配置
  Future<String> _aiCurateGo() async {
    final names = GoDataStore.places.map((p) => p.name).toList();
    final raw = await AiService.chat(
      '你是出行策划。从给定的去处列表中挑选 10 个适合周末出门的去处，'
          '只输出 JSON 字符串数组，不要输出任何其他内容。',
      names.join('、'),
    );
    final picked = (jsonDecode(raw.trim()) as List).cast<String>();
    final items = GoDataStore.places
        .where((p) => picked.contains(p.name))
        .map((p) => p.toJson())
        .toList();
    if (items.isEmpty) {
      throw Exception('AI 返回内容无法匹配去处，请重试');
    }
    await ProfileStore.save('go', 'AI精选', items);
    return 'AI精选';
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
        actions: [
          IconButton(
            tooltip: '配置集',
            icon: const Icon(Icons.folder_copy_outlined),
            onPressed: _openProfiles,
          ),
        ],
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
                            counterText: '',
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
                  _buildImagePickerRow(),
                  const SizedBox(height: 8),
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
                  leading: ItemImage(imagePath: place.imagePath, emoji: place.emoji, size: 44),
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
