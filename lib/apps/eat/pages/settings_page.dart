import '../models/food_item.dart';
import 'package:flutter/material.dart';
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
            const Text('忌口/不吃',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('选中的食材不会出现在推荐里',
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
                    decoration: const InputDecoration(
                      labelText: '自定义忌口',
                      border: OutlineInputBorder(),
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
                  child: const Text('添加'),
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
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('不重复推荐'),
                  subtitle: const Text('连续两次不推荐同一道菜'),
                  value: DataStore.settings.noRepeat,
                  onChanged: (v) {
                    setState(() => DataStore.settings.noRepeat = v);
                    DataStore.save();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('避免近期重复'),
                  subtitle: const Text('7天内吃过的不会再次推荐'),
                  value: DataStore.settings.avoidRecent,
                  onChanged: (v) {
                    setState(() => DataStore.settings.avoidRecent = v);
                    DataStore.save();
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('按季节推荐'),
                  subtitle: const Text('自动读取当前季节，当季菜品优先推荐'),
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
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.library_add, color: Colors.orange),
                  title: const Text('补充最新内置菜谱'),
                  subtitle: const Text('将最新版本内置菜谱中缺失的菜合并进来'),
                  onTap: () {
                    final added = DataStore.mergeNewDefaults();
                    setState(() {});
                    _showToast(added > 0 ? '已补充 $added 道菜' : '菜谱已是最新');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: Colors.orange),
                  title: const Text('恢复默认菜单'),
                  subtitle: const Text('重置菜肴和主食为默认列表'),
                  onTap: () => _confirmDialog('恢复默认菜单', '将替换当前所有自定义菜品，确定吗？', () {
                    DataStore.dishes = DataStore.getDefaultDishes();
                    DataStore.staples = DataStore.getDefaultStaples();
                    DataStore.save();
                    setState(() {});
                    _showToast('已恢复默认菜单');
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_sweep, color: Colors.red),
                  title: const Text('清空历史记录'),
                  onTap: () => _confirmDialog('清空历史', '确定删除所有历史记录吗？', () {
                    DataStore.clearHistory();
                    setState(() {});
                    _showToast('历史已清空');
                  }),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt, color: Colors.red),
                  title: const Text('重置所有数据'),
                  subtitle: const Text('清除所有自定义数据和历史'),
                  onTap: () => _confirmDialog('重置所有数据', '此操作不可撤销！所有自定义菜品和记录将被清除，确定吗？', () {
                    DataStore.resetToDefault();
                    setState(() {});
                    _showToast('已重置');
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: const Text('赛博乞讨'),
              subtitle: const Text('来都来了，不赏两个？♥'),
              onTap: () => _showDonationDialog(),
              trailing: const Icon(Icons.open_in_new, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          const Text('历史记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (DataStore.history.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  Text('📭', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text('还没有记录', style: TextStyle(color: Colors.grey)),
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
                subtitle: Text('$dateStr · ${h.mealTime.label} · ${h.cookMode.label}'),
              );
            }),
          const SizedBox(height: 24),
          Center(
            child: Text(
              '今天吃什么 v0.2.0',
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          }, child: const Text('确定', style: TextStyle(color: Colors.red))),
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

  void _showDonationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('赛博乞讨'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('来都来了，不赏两个？♥'),
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
                        Text('请放置收款码', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('微信扫码支持，金额随意',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
        ],
      ),
    );
  }
}
