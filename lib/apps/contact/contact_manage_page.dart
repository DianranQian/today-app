import 'package:flutter/material.dart';
import 'contact_models.dart';
import 'contact_data_store.dart';

class ContactManagePage extends StatefulWidget {
  const ContactManagePage({super.key});

  @override
  State<ContactManagePage> createState() => _ContactManagePageState();
}

class _ContactManagePageState extends State<ContactManagePage> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _relationCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  ContactFrequency _frequency = ContactFrequency.monthly;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _relationCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast('请输入称呼');
      return;
    }
    if (ContactDataStore.contacts.any((c) => c.name == name)) {
      _showToast('这个联系人已经存在了');
      return;
    }
    ContactDataStore.contacts.add(ContactItem(
      name: name,
      emoji: _emojiCtrl.text.trim().isNotEmpty ? _emojiCtrl.text.trim() : '👤',
      relation: _relationCtrl.text.trim(),
      frequency: _frequency,
    ));
    ContactDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    _relationCtrl.clear();
    setState(() {});
    _showToast('已添加 $name');
  }

  void _delete(int index) {
    final name = ContactDataStore.contacts[index].name;
    ContactDataStore.contacts.removeAt(index);
    ContactDataStore.save();
    setState(() {});
    _showToast('已删除 $name');
  }

  void _checkIn(int index) {
    ContactDataStore.checkIn(ContactDataStore.contacts[index]);
    setState(() {});
    _showToast('已打卡');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ContactDataStore.search(_searchCtrl.text);
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理联系人'),
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
                  const Text('添加联系人（隐私：数据仅存本机，不读系统通讯录）',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '称呼',
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
                        child: TextField(
                          controller: _relationCtrl,
                          decoration: const InputDecoration(
                            labelText: '关系（如：大学室友）',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<ContactFrequency>(
                          value: _frequency,
                          decoration: const InputDecoration(
                            labelText: '联系频率',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final f in ContactFrequency.values)
                              DropdownMenuItem(
                                  value: f, child: Text(f.label)),
                          ],
                          onChanged: (v) => setState(() => _frequency = v!),
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
              hintText: '按称呼或关系搜索',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (contacts.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('还没有联系人，添加一些吧', style: TextStyle(color: Colors.grey)),
            ))
          else
            ...contacts.asMap().entries.map((entry) {
              final i = ContactDataStore.contacts.indexOf(entry.value);
              final c = entry.value;
              return Dismissible(
                key: ValueKey('contact__${c.name}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _delete(i),
                child: ListTile(
                  leading: Text(c.emoji, style: const TextStyle(fontSize: 28)),
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      if (c.relation.isNotEmpty) c.relation,
                      c.frequency.label,
                      c.isOverdue ? '⚠️ 逾期 ${c.overdueDays} 天' : '上次 ${c.daysSinceContact} 天前',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '打卡已联系',
                        icon: const Icon(Icons.check_circle_outline,
                            color: Colors.green),
                        onPressed: () => _checkIn(i),
                      ),
                      IconButton(
                        tooltip: '删除',
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _delete(i),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
