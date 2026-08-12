import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_settings.dart';
import '../core/backup.dart';
import '../core/donation.dart';
import '../core/language.dart';
import '../core/theme.dart';

/// 主框架通用设置：主题色、数据导入导出、打赏
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;
  bool _amapKeyVisible = false;
  bool _deepseekKeyVisible = false;
  late final TextEditingController _amapKeyCtrl;
  late final TextEditingController _deepseekKeyCtrl;

  @override
  void initState() {
    super.initState();
    _amapKeyCtrl = TextEditingController(text: AppSettings.amapKey);
    _deepseekKeyCtrl = TextEditingController(text: AppSettings.deepseekKey);
  }

  @override
  void dispose() {
    _amapKeyCtrl.dispose();
    _deepseekKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickColor(AppId app) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${app.emoji} ${app.label} · 主题色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppSeeds.palette.entries.map((e) {
            final isCurrent = _colorOf(app) == e.key;
            return GestureDetector(
              onTap: () => Navigator.pop(ctx, e.key),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: Colors.black54, width: 3)
                      : null,
                ),
                child: Center(
                  child: Text(e.key,
                      style: TextStyle(
                          fontSize: 10,
                          color: e.value.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white)),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
    if (selected == null) return;
    setState(() {
      switch (app) {
        case AppId.eat: AppSettings.eatColor = selected;
        case AppId.go: AppSettings.goColor = selected;
        case AppId.wear: AppSettings.wearColor = selected;
        case AppId.contact: AppSettings.contactColor = selected;
        case AppId.todo: AppSettings.todoColor = selected;
      }
    });
    await AppSettings.save();
  }

  String _colorOf(AppId app) {
    switch (app) {
      case AppId.eat: return AppSettings.eatColor;
      case AppId.go: return AppSettings.goColor;
      case AppId.wear: return AppSettings.wearColor;
      case AppId.contact: return AppSettings.contactColor;
      case AppId.todo: return AppSettings.todoColor;
    }
  }

  /// 通用导出（JSON 纯数据 / ZIP 含照片）
  Future<void> _exportAs(bool withImages) async {
    setState(() => _busy = true);
    try {
      final file = withImages
          ? await BackupService.exportBackup()
          : await BackupService.exportJson();
      if (!mounted) return;
      setState(() => _busy = false);
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出完成'),
          content: Text(withImages
              ? '备份已生成（数据 + 照片）。可以分享保存，或存入下载目录。'
              : 'JSON 数据已生成（不含照片）。可以分享保存，或存入下载目录。'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'share'),
                child: const Text('分享')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'download'),
                child: const Text('存入下载')),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('关闭')),
          ],
        ),
      );
      if (action == 'share') {
        await Share.shareXFiles(
          [XFile(file.path)],
          subject: 'What to Do 数据备份',
          text: 'What to Do 数据备份',
        );
      } else if (action == 'download') {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dest = '${downloads.path}${file.uri.pathSegments.last}';
          file.copySync(dest);
          _toast('已存入下载目录');
        } else {
          _toast('无法访问下载目录，已保留在应用目录');
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('导出失败：$e');
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;
    setState(() => _busy = true);
    try {
      final restored = await BackupService.importBackup(path);
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('导入成功（$restored 项），重启应用后生效');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast('导入失败：$e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通用设置'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.palette, color: Colors.orange),
                  title: Text('主题色'),
                  subtitle: Text('为每个子应用选择喜欢的颜色'),
                ),
                for (final app in AppId.values)
                  ListTile(
                    leading: Text(app.emoji, style: const TextStyle(fontSize: 22)),
                    title: Text(app.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppSettings.seedFor(app),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(_colorOf(app),
                            style: const TextStyle(fontSize: 13)),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () => _pickColor(app),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text('API 配置（可留空）',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('附近美食、AI 分析需要对应 Key，到官网免费申请',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _amapKeyCtrl,
                    obscureText: !_amapKeyVisible,
                    decoration: InputDecoration(
                      labelText: '高德地图 Key',
                      hintText: 'console.amap.com 申请（Web服务 Key）',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _amapKeyVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _amapKeyVisible = !_amapKeyVisible),
                      ),
                    ),
                    onChanged: (_) {
                      AppSettings.amapKey = _amapKeyCtrl.text.trim();
                      AppSettings.save();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: TextField(
                    controller: _deepseekKeyCtrl,
                    obscureText: !_deepseekKeyVisible,
                    decoration: InputDecoration(
                      labelText: 'DeepSeek Key',
                      hintText: 'platform.deepseek.com 申请',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _deepseekKeyVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _deepseekKeyVisible = !_deepseekKeyVisible),
                      ),
                    ),
                    onChanged: (_) {
                      AppSettings.deepseekKey = _deepseekKeyCtrl.text.trim();
                      AppSettings.save();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language, color: Colors.orange),
                  title: const Text('语言 / Language'),
                  trailing: DropdownButton<String>(
                    value: currentLang,
                    items: const [
                      DropdownMenuItem(value: 'zh', child: Text('中文')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setLanguage(v);
                      // 重建整个 App 生效
                      Navigator.popUntil(
                          context, (route) => route.isFirst);
                      runApp(const TodayApp());
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.orange),
                  title: const Text('导出 ZIP 备份'),
                  subtitle: const Text('全部数据 + 照片，打包为 ZIP'),
                  onTap: _busy ? null : () => _exportAs(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code, color: Colors.orange),
                  title: const Text('导出 JSON 数据'),
                  subtitle: const Text('纯数据（不含照片），轻量易分享'),
                  onTap: _busy ? null : () => _exportAs(false),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download, color: Colors.orange),
                  title: const Text('导入数据备份'),
                  subtitle: const Text('从 ZIP/JSON 备份恢复（重启生效）'),
                  onTap: _busy ? null : _import,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.red),
              title: const Text('赛博乞讨'),
              subtitle: const Text('来都来了，不赏两个？♥'),
              onTap: () => showDonationDialog(context),
              trailing: const Icon(Icons.open_in_new, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'What to Do v0.1.0 · GPL-3.0 开源',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
