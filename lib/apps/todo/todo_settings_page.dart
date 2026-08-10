import 'package:flutter/material.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'todo_data_store.dart';

/// 「今天待办」设置页：导出/导入/清空
class TodoSettingsPage extends StatelessWidget {
  const TodoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: const SubAppSettingsPanel(
        appId: 'todo',
        appName: '今天待办',
        reload: TodoDataStore.load,
        onClearHistory: TodoDataStore.clearAll,
        // 待办清单无「避免近期重复」概念，隐藏该开关
        showAvoidRecent: false,
      ),
    );
  }
}
