import 'dart:io';

import 'package:flutter/material.dart';
import 'apps/contact/contact_app.dart';
import 'apps/eat/eat_app.dart';
import 'apps/go/go_app.dart';
import 'apps/todo/todo_app.dart';
import 'apps/wear/wear_app.dart';
import 'core/app_settings.dart';
import 'core/donation.dart';
import 'core/language.dart';
import 'core/plan_store.dart';
import 'core/theme.dart';
import 'core/widgets/date_selector.dart';
import 'pages/plan_page.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  await TargetDateSelector.load();
  await PlanStore.load();
  await loadLanguage();
  runApp(const TodayApp());
}

class TodayApp extends StatelessWidget {
  const TodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 监听语言变化，切换后立即重建整个 App
    return ValueListenableBuilder<String>(
      valueListenable: langNotifier,
      builder: (context, lang, _) {
        return MaterialApp(
          title: 'What to Do',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(seed: AppSeeds.eat),
          home: const MainShell(),
        );
      },
    );
  }
}

/// 主框架：底部 Tab（工具 / 计划）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 条件切换：每次切到「计划」Tab 时重建，确保读取最新计划数据
      body: _index == 0 ? const HomeEntryPage() : const PlanPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: t('工具')),
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: t('计划')),
        ],
      ),
    );
  }
}

/// 「What to Do」入口页：四个子应用 + 打赏
class HomeEntryPage extends StatelessWidget {
  const HomeEntryPage({super.key});

  void _openApp(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('今天做什么')),
        centerTitle: true,
        toolbarHeight: 44,
        actions: [
          IconButton(
            tooltip: t('通用设置'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SettingsPage(),
                )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _buildEntryCard(
            context,
            emoji: '🍜',
        title: t('今天吃什么'),
        subtitle: t('随机推荐菜谱，告别选择困难'),
            color: const Color(0xFFFF6B35),
            onTap: () => _openApp(context, const EatAppPage()),
          ),
      _buildEntryCard(
        context,
        emoji: '📍',
        title: t('今天去哪'),
        subtitle: t('随机推荐去处，出门不再纠结'),
        color: const Color(0xFF42A5F5),
        onTap: () => _openApp(context, const GoAppPage()),
      ),
      _buildEntryCard(
        context,
        emoji: '👕',
        title: t('今天穿什么'),
        subtitle: t('按季节随机搭配，轻松出门'),
        color: const Color(0xFFEC407A),
        onTap: () => _openApp(context, const WearAppPage()),
      ),
      _buildEntryCard(
        context,
        emoji: '📞',
        title: t('今天联系谁'),
        subtitle: t('提醒联系久未问候的亲友'),
        color: const Color(0xFF7E57C2),
        onTap: () => _openApp(context, const ContactAppPage()),
      ),
      _buildEntryCard(
        context,
        emoji: '📋',
        title: t('今天待办'),
        subtitle: t('每日待办清单，按日期管理'),
        color: const Color(0xFF8D6E63),
        onTap: () => _openApp(context, const TodoAppPage()),
          ),
          const SizedBox(height: 24),
          // 打赏入口（iOS 审核风险，构建时隐藏）
          if (!Platform.isIOS)
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showDonationDialog(context),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    t('What to Do v0.1.0 · ♥ 支持一下'),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ),
            )
          else
            Center(
              child: Text(
                'What to Do v0.1.0',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
