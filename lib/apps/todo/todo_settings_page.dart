import 'package:flutter/material.dart';
import '../../core/language.dart';
import '../../core/widgets/sub_app_settings_panel.dart';
import 'todo_data_store.dart';

/// 「今天待办」设置页：导出/导入/清空
class TodoSettingsPage extends StatelessWidget {
  const TodoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('设置', 'Settings')),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: SubAppSettingsPanel(
        appId: 'todo',
        appName: t('今天待办', 'Tasks'),
        reload: TodoDataStore.load,
        onClearHistory: TodoDataStore.clearAll,
        // 待办清单无「避免近期重复」「随机抽取」概念，隐藏
        showAvoidRecent: false,
        showRandomPool: false,
      ),
    );
  }
}
