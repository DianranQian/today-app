import 'package:flutter/material.dart';
import '../../core/season.dart';
import '../../core/image_helper.dart';
import 'dart:convert';
import '../../core/profile_store.dart';
import '../../core/services/ai_service.dart';
import '../../core/widgets/profile_dialog.dart';
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
  WearGender _gender = WearGender.unisex;
  WearGroup _group = WearGroup.student;
  WearStyle _style = WearStyle.casual;
  int? _tempMin;
  int? _tempMax;
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
      gender: _gender,
      group: _group,
      style: _style,
      tempMin: _tempMin,
      tempMax: _tempMax,
      imagePath: _imagePath,
    ));
    WearDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    _imagePath = null;
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


  Future<void> _pickImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _imagePath = p);
  }

  Widget _buildImagePickerRow() {
    return Row(
      children: [
        ItemImage(imagePath: _imagePath, emoji: '👕', size: 48),
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
      appId: 'wear',
      currentItems: WearDataStore.outfits.map((o) => o.toJson()).toList(),
      applyItems: (items) {
        setState(() {
          WearDataStore.outfits = items.map((e) => OutfitItem.fromJson(e)).toList();
          WearDataStore.save();
        });
      },
      aiCurate: _aiCurateWear,
      exportBaseName: 'wear_outfits',
    );
  }

  /// AI 汇总：挑选一组适合日常的穿搭，存为「AI精选」配置
  Future<String> _aiCurateWear() async {
    final names = WearDataStore.outfits.map((o) => o.name).toList();
    final raw = await AiService.chat(
      '你是穿搭顾问。从给定的穿搭列表中挑选 10 套适合日常出门的搭配，'
          '只输出 JSON 字符串数组，不要输出任何其他内容。',
      names.join('、'),
    );
    final picked = (jsonDecode(raw.trim()) as List).cast<String>();
    final items = WearDataStore.outfits
        .where((o) => picked.contains(o.name))
        .map((o) => o.toJson())
        .toList();
    if (items.isEmpty) {
      throw Exception('AI 返回内容无法匹配穿搭，请重试');
    }
    await ProfileStore.save('wear', 'AI精选', items);
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
    final outfits = WearDataStore.search(_searchCtrl.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理穿搭'),
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
                        child: DropdownButtonFormField<WearGender>(
                          value: _gender,
                          decoration: const InputDecoration(
                            labelText: '性别',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final g in WearGender.values)
                              DropdownMenuItem(
                                  value: g, child: Text(g.label)),
                          ],
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<WearGroup>(
                          value: _group,
                          decoration: const InputDecoration(
                            labelText: '人群',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final g in WearGroup.values)
                              if (g != WearGroup.all)
                                DropdownMenuItem(
                                    value: g, child: Text(g.label)),
                          ],
                          onChanged: (v) => setState(() => _group = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<WearStyle>(
                          value: _style,
                          decoration: const InputDecoration(
                            labelText: '风格',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final s in WearStyle.values)
                              if (s != WearStyle.all)
                                DropdownMenuItem(
                                    value: s, child: Text(s.label)),
                          ],
                          onChanged: (v) => setState(() => _style = v!),
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
                  leading: ItemImage(imagePath: outfit.imagePath, emoji: outfit.emoji, size: 44),
                  title: Text(outfit.name),
                  subtitle: Text('${outfit.scene.label} · ${outfit.gender.label} · ${outfit.group.label} · ${outfit.style.label} · $seasonTag季'),
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
