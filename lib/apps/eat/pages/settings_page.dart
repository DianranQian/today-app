import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/backup.dart';
import '../../../core/language.dart';
import '../../../core/widgets/scheme_random_pool.dart';
import '../models/food_item.dart';
import '../data/data_store.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _avoidCustomCtrl;

  @override
  void initState() {
    super.initState();
    _avoidCustomCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _avoidCustomCtrl.dispose();
    super.dispose();
  }

  void _toggleAvoid(String word) {
    setState(() {
      if (DataStore.avoidIngredients.contains(word)) {
        DataStore.avoidIngredients.remove(word);
      } else {
        DataStore.avoidIngredients.add(word);
      }
    });
    DataStore.save();
  }

  void _addCustomAvoid() {
    final w = _avoidCustomCtrl.text.trim();
    if (w.isEmpty) return;
    if (!DataStore.avoidIngredients.contains(w)) {
      setState(() => DataStore.avoidIngredients.add(w));
      DataStore.save();
    }
    _avoidCustomCtrl.clear();
  }

  /// 忌口设置卡
  Widget _buildAvoidCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('忌口/不吃', 'Avoid'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(t('选中的食材不会出现在推荐里',
                'Selected ingredients will not be recommended'),
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DataStore.avoidPresets.map((w) {
                final selected = DataStore.avoidIngredients.contains(w);
                return FilterChip(
                  label: Text(w),
                  selected: selected,
                  onSelected: (_) => _toggleAvoid(w),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _avoidCustomCtrl,
                    decoration: InputDecoration(
                      labelText: t('自定义忌口', 'Custom avoid list'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addCustomAvoid(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCustomAvoid,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(t('添加', 'Add')),
                ),
              ],
            ),
            if (DataStore.avoidIngredients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: DataStore.avoidIngredients.map((w) => Chip(
                  label: Text(w, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => _toggleAvoid(w),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置', 'Settings')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(t('不重复推荐', 'No repeats')),
                  subtitle: Text(t('连续两次不推荐同一道菜', 'Never recommend the same dish twice in a row')),
                  value: DataStore.settings.noRepeat,
                  onChanged: (v) {
                    setState(() => DataStore.settings.noRepeat = v);
                    DataStore.save();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(t('避免近期重复', 'Avoid recent repeats')),
                  subtitle: Text(t('7天内吃过的不会再次推荐', 'Dishes eaten in the last 7 days will not be recommended')),
                  value: DataStore.settings.avoidRecent,
                  onChanged: (v) {
                    setState(() => DataStore.settings.avoidRecent = v);
                    DataStore.save();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(t('按季节推荐', 'Seasonal picks')),
                  subtitle: Text(t('自动读取当前季节，当季菜品优先推荐', 'Reads the current season and prioritizes in-season dishes')),
                  value: DataStore.settings.seasonRecommend,
                  onChanged: (v) {
                    setState(() => DataStore.settings.seasonRecommend = v);
                    DataStore.save();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildAvoidCard(),
          const SizedBox(height: 12),
          SchemeRandomPoolPicker(appId: 'eat'),
          const SizedBox(height: 12),
          // 本应用数据导入导出
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.orange),
                  title: Text(t('导出本应用数据', 'Export app data')),
                  subtitle: Text(t('菜谱/饮品/历史（ZIP 含照片，JSON 纯数据）', 'Recipes/drinks/history (ZIP includes photos, JSON is data only)')),
                  onTap: () => _exportApp(),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.orange),
                  title: Text(t('导入本应用数据', 'Import app data')),
                  subtitle: Text(t('从 ZIP/JSON 恢复（立即生效）', 'Restore from ZIP/JSON (takes effect immediately)')),
                  onTap: () => _importApp(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_add, color: Colors.orange),
                  title: Text(t('补充最新内置菜谱', 'Merge latest built-in recipes')),
                  subtitle: Text(t('将最新版本内置菜谱中缺失的菜合并进来', 'Merge recipes missing from the latest built-in list')),
                  onTap: () {
                    final added = DataStore.mergeNewDefaults();
                    setState(() {});
                    _showToast(added > 0 ? t('已补充 $added 道菜', 'Added $added recipes') : t('菜谱已是最新', 'Recipes are up to date'));
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: Text(t('恢复默认菜单', 'Restore default menu')),
                  subtitle: Text(t('重置菜肴和主食为默认列表', 'Reset dishes and staples to defaults')),
                  onTap: () => _confirmDialog(t('恢复默认菜单', 'Restore default menu'), t('将替换当前所有自定义菜品，确定吗？', 'This will replace all your custom dishes. Continue?'), () {
                    DataStore.dishes = DataStore.getDefaultDishes();
                    DataStore.staples = DataStore.getDefaultStaples();
                    DataStore.save();
                    setState(() {});
                    _showToast(t('已恢复默认菜单', 'Default menu restored'));
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text(t('清空历史记录', 'Clear history')),
                  onTap: () => _confirmDialog(t('清空历史', 'Clear history'), t('确定删除所有历史记录吗？', 'Delete all history records?'), () {
                    DataStore.clearHistory();
                    setState(() {});
                    _showToast(t('历史已清空', 'History cleared'));
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.red),
                  title: Text(t('重置所有数据', 'Reset all data')),
                  subtitle: Text(t('清除所有自定义数据和历史', 'Clear all custom data and history')),
                  onTap: () => _confirmDialog(t('重置所有数据', 'Reset all data'), t('此操作不可撤销！所有自定义菜品和记录将被清除，确定吗？', 'This cannot be undone! All custom dishes and records will be deleted. Continue?'), () {
                    DataStore.resetToDefault();
                    setState(() {});
                    _showToast(t('已重置', 'Reset done'));
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: Text(t('赛博乞讨', 'Tip jar')),
              subtitle: Text(t('来都来了，不赏两个？♥', 'Since you are here, how about a tip? ♥')),
              onTap: () => _showDonationDialog(),
              trailing: const Icon(Icons.open_in_new, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Text(t('历史记录', 'History'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (DataStore.history.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Text('📭', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  Text(t('还没有记录', 'No records yet'), style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ))
          else
            ...DataStore.history.take(50).map((h) {
              final dateStr = '${h.date.month}/${h.date.day} '
                  '${h.date.hour.toString().padLeft(2, "0")}:${h.date.minute.toString().padLeft(2, "0")}';
              return ListTile(
                dense: true,
                leading: Text(h.dishEmoji, style: const TextStyle(fontSize: 24)),
                title: Text([
                  h.dishName,
                  if (h.stapleName != null) h.stapleName!,
                  if (h.drinkName != null) h.drinkName!,
                ].join(' + ')),
                subtitle: Text(t('$dateStr · ${h.mealTime.label} · ${h.cookMode.label}',
                    '$dateStr · ${h.mealTime.label} · ${h.cookMode.label}')),
              );
            }),
          const SizedBox(height: 24),
          Center(
            child: Text(
              t('今天吃什么 v0.2.0', 'What to Eat Today v0.2.0'),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('取消', 'Cancel'))),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          }, child: Text(t('确定', 'Confirm'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 导出本应用数据（弹窗选 ZIP/JSON 并分享/存下载）
  Future<void> _exportApp() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('导出「今天吃什么」数据', 'Export What to Eat data')),
        content: Text(t('ZIP 含照片，JSON 为纯数据。', 'ZIP includes photos; JSON is data only.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'zip'),
              child: Text(t('ZIP（含照片）', 'ZIP (with photos)'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'json'),
              child: Text(t('JSON（纯数据）', 'JSON (data only)'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('取消', 'Cancel'))),
        ],
      ),
    );
    if (action == null) return;
    try {
      final file = await BackupService.exportApp('eat',
          withImages: action == 'zip');
      if (!mounted) return;
      final shareAction = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('导出完成', 'Export complete')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'share'),
                child: Text(t('分享', 'Share'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('关闭', 'Close'))),
          ],
        ),
      );
      if (shareAction == 'share') {
        await Share.shareXFiles([XFile(file.path)],
            subject: t('今天吃什么 数据', 'What to Eat data'), text: t('今天吃什么 数据', 'What to Eat data'));
      }
    } catch (e) {
      _showToast(t('导出失败：$e', 'Export failed: $e'));
    }
  }

  /// 导入本应用数据（写回 + 热更新）
  Future<void> _importApp() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    try {
      final restored = await BackupService.importApp('eat', path);
      await DataStore.load();
      if (!mounted) return;
      setState(() {});
      _showToast(t('导入成功（$restored 项），已生效', 'Import successful ($restored items), now active'));
    } catch (e) {
      _showToast(t('导入失败：$e', 'Import failed: $e'));
    }
  }

  void _showDonationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Text(t('赛博乞讨', 'Tip jar')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t('来都来了，不赏两个？♥', 'Since you are here, how about a tip? ♥')),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/wechat_qr.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (ctx, err, stack) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 4),
                        Text(t('请放置收款码', 'Place your payment QR code here'),
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(t('微信扫码支持，金额随意',
                'Scan with WeChat to support us, any amount is welcome'),
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t('关闭', 'Close'))),
        ],
      ),
    );
  }
}
