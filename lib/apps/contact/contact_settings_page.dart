import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        title: const Text('设置'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: SubAppSettingsPanel(
        appId: 'contact',
        appName: '今天联系谁',
        reload: ContactDataStore.load,
        onClearHistory: () {
          // 联系人无历史概念，清空所有联系人
          ContactDataStore.contacts.clear();
          ContactDataStore.save();
        },
        extra: Card(
          child: ListTile(
            leading: const Icon(Icons.hourglass_empty, color: Colors.orange),
            title: const Text('新增联系人默认频率'),
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
