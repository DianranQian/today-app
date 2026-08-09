import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/profile_dialog.dart';
import '../../core/image_helper.dart';
import 'contact_actions.dart';
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
  String? _imagePath;

  // 联系方式编辑
  final List<ContactMethod> _newContacts = [];
  ContactType _contactType = ContactType.phone;
  final _contactValueCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 读取设置页配置的默认频率
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      setState(() => _frequency = ContactFrequencyExt.fromString(
          prefs.getString('contact_default_frequency') ?? 'monthly'));
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _relationCtrl.dispose();
    _searchCtrl.dispose();
    _contactValueCtrl.dispose();
    super.dispose();
  }

  void _addContactMethod() {
    final v = _contactValueCtrl.text.trim();
    if (v.isEmpty) {
      _showToast('请输入联系方式');
      return;
    }
    setState(() {
      _newContacts.add(ContactMethod(type: _contactType, value: v));
      _contactValueCtrl.clear();
    });
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
      imagePath: _imagePath,
      contacts: List.of(_newContacts),
    ));
    ContactDataStore.save();
    _nameCtrl.clear();
    _emojiCtrl.clear();
    _relationCtrl.clear();
    _imagePath = null;
    _newContacts.clear();
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


  Future<void> _pickImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _imagePath = p);
  }

  Widget _buildImagePickerRow() {
    return Row(
      children: [
        ItemImage(imagePath: _imagePath, emoji: '👤', size: 48),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: const Text('添加头像'),
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

  /// 配置集：另存为 / 应用 / 导出
  Future<void> _openProfiles() async {
    await showProfileDialog(
      context,
      appId: 'contact',
      currentItems: ContactDataStore.contacts.map((c) => c.toJson()).toList(),
      applyItems: (items) {
        setState(() {
          ContactDataStore.contacts = items.map((e) => ContactItem.fromJson(e)).toList();
          ContactDataStore.save();
        });
      },
      exportBaseName: 'contact_contacts',
    );
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
                  // 联系方式编辑
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ContactType>(
                          value: _contactType,
                          decoration: const InputDecoration(
                            labelText: '类型',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            for (final t in ContactType.values)
                              DropdownMenuItem(
                                  value: t, child: Text(t.label)),
                          ],
                          onChanged: (v) => setState(() => _contactType = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _contactValueCtrl,
                          decoration: const InputDecoration(
                            labelText: '手机号/账号',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addContactMethod(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _addContactMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('添加'),
                      ),
                    ],
                  ),
                  if (_newContacts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _newContacts.asMap().entries.map((e) {
                        final m = e.value;
                        return Chip(
                          avatar: Text(m.type.icon),
                          label: Text('${m.type.label}: ${m.value}',
                              style: const TextStyle(fontSize: 12)),
                          onDeleted: () =>
                              setState(() => _newContacts.removeAt(e.key)),
                        );
                      }).toList(),
                    ),
                  ],
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
                  leading: ItemImage(imagePath: c.imagePath, emoji: c.emoji, size: 44),
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      if (c.relation.isNotEmpty) c.relation,
                      c.frequency.label,
                      if (c.contacts.isNotEmpty)
                        c.contacts
                            .map((m) => '${m.type.icon}${m.value}')
                            .join('  '),
                      c.isOverdue ? '⚠️ 逾期 ${c.overdueDays} 天' : '上次 ${c.daysSinceContact} 天前',
                    ].join(' · '),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.contacts.isNotEmpty)
                        IconButton(
                          tooltip: '拨打/复制',
                          icon: const Icon(Icons.phone_in_talk,
                              color: Colors.blue),
                          onPressed: () =>
                              ContactActions.perform(context, c.contacts.first),
                        ),
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
