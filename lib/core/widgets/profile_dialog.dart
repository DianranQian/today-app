import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../language.dart';
import '../profile_store.dart';

/// 配置管理弹窗（通用）：另存为 / 应用 / 导出 / AI 汇总 / 删除
///
/// [appId] 子应用标识；[currentItems] 当前数据快照（toJson 列表）；
/// [applyItems] 应用配置到当前数据（load 后替换 + setState）；
/// [aiCurate] 可选：AI 汇总（返回配置名）；[exportBaseName] 导出文件名前缀。
Future<void> showProfileDialog(
  BuildContext context, {
  required String appId,
  required List<Map<String, dynamic>> currentItems,
  required void Function(List<Map<String, dynamic>>) applyItems,
  Future<String> Function()? aiCurate,
  required String exportBaseName,
}) async {
  await showDialog(
    context: context,
    builder: (ctx) => _ProfileDialog(
      appId: appId,
      currentItems: currentItems,
      applyItems: applyItems,
      aiCurate: aiCurate,
      exportBaseName: exportBaseName,
    ),
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.appId,
    required this.currentItems,
    required this.applyItems,
    required this.aiCurate,
    required this.exportBaseName,
  });

  final String appId;
  final List<Map<String, dynamic>> currentItems;
  final void Function(List<Map<String, dynamic>>) applyItems;
  final Future<String> Function()? aiCurate;
  final String exportBaseName;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  List<String> _names = [];
  bool _busy = false;
  final _newNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final names = await ProfileStore.profileNames(widget.appId);
    if (mounted) setState(() => _names = names);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _saveAs() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) {
      _toast(t('请输入配置名称'));
      return;
    }
    await ProfileStore.save(widget.appId, name, widget.currentItems);
    _newNameCtrl.clear();
    _toast(t('已保存配置「$name」', 'Profile "$name" saved'));
    await _refresh();
  }

  Future<void> _apply(String name) async {
    setState(() => _busy = true);
    final items = await ProfileStore.load(widget.appId, name);
    if (items.isEmpty) {
      _toast(t('配置数据为空'));
      setState(() => _busy = false);
      return;
    }
    widget.applyItems(items);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pop(context);
    _toast(t('已应用配置「$name」', 'Profile "$name" applied'));
  }

  Future<void> _export(String name) async {
    final items = await ProfileStore.load(widget.appId, name);
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/today_exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final fname =
        '${widget.exportBaseName}_${name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.json';
    File('${dir.path}/$fname').writeAsStringSync(jsonEncode(items));
    _toast(t('已导出：$fname', 'Exported: $fname'));
  }

  Future<void> _delete(String name) async {
    await ProfileStore.remove(widget.appId, name);
    _toast(t('已删除配置「$name」', 'Profile "$name" deleted'));
    await _refresh();
  }

  Future<void> _aiCurate() async {
    final curator = widget.aiCurate;
    if (curator == null) {
      _toast(t('该子应用暂不支持 AI 汇总'));
      return;
    }
    setState(() => _busy = true);
    try {
      final name = await curator();
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t('AI 汇总完成：已保存配置「$name」',
          'AI summary done: profile "$name" saved'));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _toast(t('AI 汇总失败：${e.toString().replaceFirst('Exception: ', '')}',
          'AI summary failed: ${e.toString().replaceFirst('Exception: ', '')}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return AlertDialog(
      title: Text(t('配置管理')),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.aiCurate != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _aiCurate,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_busy
                      ? t('AI 汇总中...')
                      : t('AI 汇总生成配置')),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameCtrl,
                    decoration: InputDecoration(
                      labelText: t('新配置名称'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveAs,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(t('另存为')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(t('我的配置'), style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),
            Flexible(
              child: _names.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                      t('暂无自定义配置（「默认」为内置数据）'),
                      style:
                          const TextStyle(fontSize: 12, color: Colors.grey)),
                )
              : ListView(
                      shrinkWrap: true,
                      children: _names.map((name) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.folder, size: 20),
                          title: Text(name,
                              style: const TextStyle(fontSize: 14)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: t('应用'),
                                icon: const Icon(Icons.check_circle_outline,
                                    color: Colors.green),
                                onPressed: _busy
                                    ? null
                                    : () => _apply(name),
                              ),
                              IconButton(
                                tooltip: t('导出'),
                                icon: const Icon(Icons.ios_share,
                                    color: Colors.blue),
                                onPressed: () => _export(name),
                              ),
                              IconButton(
                                tooltip: t('删除'),
                                icon: const Icon(Icons.delete_outline,
                                    color: Colors.red),
                                onPressed: () => _delete(name),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('关闭'))),
      ],
    );
  }
}
