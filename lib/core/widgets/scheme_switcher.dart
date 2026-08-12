import 'package:flutter/material.dart';
import '../language.dart';
import '../scheme_store.dart';

/// AppBar 方案切换入口：显示当前方案名，点击弹出切换弹窗
class SchemeSwitcherButton extends StatefulWidget {
  const SchemeSwitcherButton({
    super.key,
    required this.appId,
    required this.onSwitched,
  });

  final String appId;

  /// 切换/新建后刷新数据（调用对应 store.load()）
  final Future<void> Function() onSwitched;

  @override
  State<SchemeSwitcherButton> createState() => _SchemeSwitcherButtonState();
}

class _SchemeSwitcherButtonState extends State<SchemeSwitcherButton> {
  String _name = '';

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onChanged);
    _loadName();
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (SchemeStore.notifier.value == widget.appId) _loadName();
  }

  Future<void> _loadName() async {
    final name = await SchemeStore.current(widget.appId);
    if (mounted) setState(() => _name = name);
  }

  Future<void> _open() async {
    await showDialog<void>(
      context: context,
      builder: (_) => SchemeSwitcherDialog(
        appId: widget.appId,
        onSwitched: widget.onSwitched,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _open,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      icon: const Icon(Icons.swap_horiz, size: 18),
      label: Text(
        _name.isEmpty ? SchemeStore.defaultSchemeName(widget.appId) : _name,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

/// 工作区方案切换弹窗：
/// 方案列表（当前 ✓）+ 新建 / 重命名 / 删除 + 切换
class SchemeSwitcherDialog extends StatefulWidget {
  const SchemeSwitcherDialog({
    super.key,
    required this.appId,
    required this.onSwitched,
  });

  final String appId;

  /// 切换/新建后刷新数据（调用对应 store.load()）
  final Future<void> Function() onSwitched;

  @override
  State<SchemeSwitcherDialog> createState() => _SchemeSwitcherDialogState();
}

class _SchemeSwitcherDialogState extends State<SchemeSwitcherDialog> {
  late Future<List<String>> _schemesFuture;
  late Future<String> _currentFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _schemesFuture = SchemeStore.list(widget.appId);
    _currentFuture = SchemeStore.current(widget.appId);
  }

  Future<void> _switchTo(String name) async {
    await SchemeStore.switchTo(widget.appId, name);
    await widget.onSwitched();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _create() async {
    final name = await _promptName(
        t('新建方案', 'New Scheme'), t('方案名称', 'Scheme name'));
    if (name == null || name.isEmpty) return;
    try {
      await SchemeStore.create(widget.appId, name);
      await widget.onSwitched();
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('创建失败：$e', 'Create failed: $e')),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _rename(String oldName) async {
    final name = await _promptName(
        t('重命名方案', 'Rename Scheme'), t('新名称', 'New name'), oldName);
    if (name == null || name.isEmpty || name == oldName) return;
    try {
      await SchemeStore.rename(widget.appId, oldName, name);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('重命名失败：$e', 'Rename failed: $e')),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _remove(String name, String current) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('删除方案', 'Delete Scheme')),
        content: Text(t('确定删除「$name」及其全部数据吗？此操作不可撤销。',
            'Delete "$name" and all its data? This cannot be undone.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('取消', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t('删除', 'Delete'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (name == current) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('不能删除当前方案', 'Cannot delete the current scheme')),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }
    try {
      await SchemeStore.remove(widget.appId, name);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('删除失败：$e', 'Delete failed: $e')),
            behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<String?> _promptName(String title, String label,
      [String initial = '']) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('取消', 'Cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(t('确定', 'OK'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('切换方案', 'Switch Scheme')),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<String>>(
          future: _schemesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(t('加载失败', 'Failed to load'));
            }
            final schemes = snapshot.data ?? [];
            return FutureBuilder<String>(
              future: _currentFuture,
              builder: (context, cur) {
                final current = cur.data ?? '';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: schemes.length,
                        itemBuilder: (context, i) {
                          final name = schemes[i];
                          final isCurrent = name == current;
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              isCurrent ? Icons.check_circle : Icons.menu_book_outlined,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            title: Text(name),
                            trailing: isCurrent
                                ? null
                                : PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        size: 20, color: Colors.grey),
                                    onSelected: (action) {
                                      if (action == 'rename') {
                                        _rename(name);
                                      } else if (action == 'delete') {
                                        _remove(name, current);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'rename',
                                          child: Text(t('重命名', 'Rename'))),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text(t('删除', 'Delete'))),
                                    ],
                                  ),
                            onTap: isCurrent
                                ? null
                                : () => _switchTo(name),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add, color: Colors.green),
                      title: Text(t('新建方案', 'New Scheme')),
                      onTap: _create,
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('关闭', 'Close'))),
      ],
    );
  }
}
