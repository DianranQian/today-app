import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/language.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'contact_data_store.dart';
import 'contact_models.dart';

/// 「今天联系谁」设置页（含新增联系人默认频率）
class ContactSettingsPage extends StatefulWidget {
  const ContactSettingsPage({super.key});

  @override
  State<ContactSettingsPage> createState() => _ContactSettingsPageState();
}

class _ContactSettingsPageState extends State<ContactSettingsPage> {
  ContactFrequency _defaultFrequency = ContactFrequency.monthly;

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _defaultFrequency = ContactFrequencyExt.fromString(
        prefs.getString('contact_default_frequency') ?? 'monthly'));
  }

  Future<void> _savePref(ContactFrequency f) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('contact_default_frequency', f.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置')),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: SubAppSettingsPanel(
        appId: 'contact',
        appName: t('今天联系谁'),
        reload: ContactDataStore.load,
        onClearHistory: () {
          // 联系人无历史概念，清空所有联系人（需二次确认）
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(t('清空所有联系人')),
              content: Text(t('将删除全部联系人，此操作不可撤销。确定吗？')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(t('取消'))),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ContactDataStore.contacts.clear();
                    ContactDataStore.save();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t('所有联系人已清空')),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Text(t('确定'),
                      style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        extra: Card(
          child: ListTile(
            leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
            title: Text(t('新增联系人默认频率')),
            trailing: DropdownButton<ContactFrequency>(
              value: _defaultFrequency,
              items: [
                for (final f in ContactFrequency.values)
                  DropdownMenuItem(value: f, child: Text(f.label)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _defaultFrequency = v);
                _savePref(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}
