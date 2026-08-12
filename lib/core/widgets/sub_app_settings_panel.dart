import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../backup.dart';
import '../language.dart';
import 'scheme_random_pool.dart';

/// 子应用设置面板（通用）：
/// 避免近期重复开关、清空历史、导出/导入本应用数据
class SubAppSettingsPanel extends StatefulWidget {
  const SubAppSettingsPanel({
    super.key,
    required this.appId,
    required this.appName,
    required this.reload,
    required this.onClearHistory,
    this.extra,
    this.showAvoidRecent = true,
    this.showRandomPool = true,
    this.clearLabel,
  });

  /// 子应用标识（eat/go/wear/contact/todo）
  final String appId;
  final String appName;

  /// 导入后热更新内存（调用对应 store.load()）
  final Future<void> Function() reload;

  /// 清空历史
  final VoidCallback onClearHistory;

  /// 额外设置项（如联系谁的默认频率）
  final Widget? extra;

  /// 是否显示「避免近期重复」开关（待办等无此概念的应用传 false）
  final bool showAvoidRecent;

  /// 是否显示「参与随机的方案」多选（待办无随机功能传 false）
  final bool showRandomPool;

  /// 清空按钮文案（null 时用默认「清空历史」）
  final String? clearLabel;

  @override
  State<SubAppSettingsPanel> createState() => _SubAppSettingsPanelState();
}

class _SubAppSettingsPanelState extends State<SubAppSettingsPanel> {
  bool _avoidRecent = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadAvoidRecent();
  }

  Future<void> _loadAvoidRecent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _avoidRecent = prefs.getBool('${widget.appId}_avoid_recent') ?? true);
  }

  Future<void> _saveAvoidRecent(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${widget.appId}_avoid_recent', v);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export(bool withImages) async {
    setState(() => _busy = true);
    try {
      final file = await BackupService.exportApp(widget.appId,
          withImages: withImages);
      if (!mounted) return;
      setState(() => _busy = false);
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('导出完成')),
          content: Text(withImages
              ? t('已生成「${widget.appName}」数据备份（含该应用的照片）。',
                  'Backup created for "${widget.appName}" (includes photos).')
              : t('已生成「${widget.appName}」纯数据 JSON（不含照片）。',
                  'Exported "${widget.appName}" as data-only JSON (no photos).')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'share'),
                child: Text(t('分享'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, 'download'),
                child: Text(t('存入下载'))),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('关闭'))),
          ],
        ),
      );
      if (action == 'share') {
        await Share.shareXFiles([XFile(file.path)],
            subject: t('${widget.appName} 数据', '${widget.appName} data'),
            text: t('${widget.appName} 数据', '${widget.appName} data'));
      } else if (action == 'download') {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) {
          final dest = '${downloads.path}${file.uri.pathSegments.last}';
          file.copySync(dest);
          _toast(t('已存入下载目录'));
        } else {
          _toast(t('无法访问下载目录，已保留在应用目录'));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t('导出失败：$e', 'Export failed: $e'));
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
      final restored = await BackupService.importApp(widget.appId, path);
      await widget.reload();
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t('导入成功（$restored 项），已生效',
          'Import successful ($restored items)'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t('导入失败：$e', 'Import failed: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.showAvoidRecent)
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: Text(t('避免近期重复')),
                  subtitle: Text(t('7 天内用过的不会再次推荐')),
                  value: _avoidRecent,
                  onChanged: (v) {
                    setState(() => _avoidRecent = v);
                    _saveAvoidRecent(v);
                  },
                ),
              ],
            ),
          ),
        if (widget.extra != null) ...[
          const SizedBox(height: 12),
          widget.extra!,
        ],
        if (widget.showRandomPool) ...[
          const SizedBox(height: 12),
          SchemeRandomPoolPicker(appId: widget.appId),
        ],
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file, color: Colors.orange),
                title: Text(t('导出 ZIP 备份')),
                subtitle: Text(t('${widget.appName} 数据 + 该应用照片',
                    '${widget.appName} data + photos')),
                onTap: _busy ? null : () => _export(true),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code, color: Colors.orange),
                title: Text(t('导出 JSON 数据')),
                subtitle: Text(t('${widget.appName} 纯数据，轻量易分享',
                    '${widget.appName} data only, easy to share')),
                onTap: _busy ? null : () => _export(false),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download, color: Colors.orange),
                title: Text(t('导入数据')),
                subtitle: Text(t('从 ZIP/JSON 恢复（立即生效）')),
                onTap: _busy ? null : _import,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep, color: Colors.red),
                title: Text(widget.clearLabel ??
                    t('清空历史')),
                onTap: () {
                  widget.onClearHistory();
                  _toast(t('已清空'));
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(t('「${widget.appName}」数据仅存本机',
              '"${widget.appName}" data stays on this device only'),
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ),
      ],
    );
  }
}
