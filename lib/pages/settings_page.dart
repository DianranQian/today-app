import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_settings.dart';
import '../core/backup.dart';
import '../core/donation.dart';
import '../core/theme.dart';

/// 主框架通用设置：主题色、数据导入导出、打赏
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _busy = false;

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
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final file = await BackupService.exportBackup();
      if (!mounted) return;
      setState(() => _busy = false);
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导出完成'),
          content: const Text('备份已生成，包含全部数据与照片。可以分享保存，或存入下载目录。'),
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
          subject: '今天做什么 数据备份',
          text: '今天做什么 数据备份',
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
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.orange),
                  title: const Text('导出数据备份'),
                  subtitle: const Text('全部数据 + 照片，打包为 ZIP'),
                  onTap: _busy ? null : _export,
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
              '今天做什么 v0.2.0 · GPL-3.0 开源',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
