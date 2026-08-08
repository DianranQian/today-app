import 'package:flutter/material.dart';
import 'apps/contact/contact_app.dart';
import 'apps/eat/eat_app.dart';
import 'apps/go/go_app.dart';
import 'apps/wear/wear_app.dart';
import 'core/app_settings.dart';
import 'core/donation.dart';
import 'core/theme.dart';
import 'pages/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.load();
  runApp(const TodayApp());
}

class TodayApp extends StatelessWidget {
  const TodayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今天做什么',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(seed: AppSeeds.eat),
      home: const HomeEntryPage(),
    );
  }
}

/// 「今天做什么」入口页：四个子应用 + 打赏
class HomeEntryPage extends StatelessWidget {
  const HomeEntryPage({super.key});

  void _openApp(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今天做什么'),
        centerTitle: true,
        toolbarHeight: 44,
        actions: [
          IconButton(
            tooltip: '通用设置',
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
            title: '今天吃什么',
            subtitle: '随机推荐菜谱，告别选择困难',
            color: const Color(0xFFFF6B35),
            onTap: () => _openApp(context, const EatAppPage()),
          ),
          _buildEntryCard(
            context,
            emoji: '📍',
            title: '今天去哪',
            subtitle: '随机推荐去处，出门不再纠结',
            color: const Color(0xFF4CAF50),
            onTap: () => _openApp(context, const GoAppPage()),
          ),
          _buildEntryCard(
            context,
            emoji: '👕',
            title: '今天穿什么',
            subtitle: '按季节随机搭配，轻松出门',
            color: const Color(0xFF42A5F5),
            onTap: () => _openApp(context, const WearAppPage()),
          ),
          _buildEntryCard(
            context,
            emoji: '📞',
            title: '今天联系谁',
            subtitle: '提醒联系久未问候的亲友',
            color: const Color(0xFF7E57C2),
            onTap: () => _openApp(context, const ContactAppPage()),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              onPressed: () => showDonationDialog(context),
              icon: const Icon(Icons.favorite, color: Colors.red, size: 18),
              label: const Text('赛博乞讨'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '今天做什么 v0.1.0 · 开源项目',
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
