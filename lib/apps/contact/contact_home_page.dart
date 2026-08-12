import 'package:flutter/material.dart';
import '../../core/language.dart';
import 'contact_actions.dart';
import 'contact_models.dart';
import '../../core/image_helper.dart';
import '../../core/plan_store.dart';
import '../../core/scheme_store.dart';
import '../../core/widgets/add_to_plan_dialog.dart';
import '../../core/widgets/scheme_switcher.dart';
import 'contact_data_store.dart';

class ContactHomePage extends StatefulWidget {
  const ContactHomePage({super.key});

  @override
  State<ContactHomePage> createState() => _ContactHomePageState();
}

class _ContactHomePageState extends State<ContactHomePage> {
  ContactItem? _picked;

  /// 随机池缓存（多方案合并），null = 用当前方案内存数据
  List<ContactItem>? _poolCache;

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onSchemeChanged);
    _reloadPool();
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value == 'contact') _reloadPool();
  }

  Future<void> _reloadPool() async {
    final pool = await ContactDataStore.loadRandomPool();
    if (mounted) setState(() => _poolCache = pool);
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onSchemeChanged);
    super.dispose();
  }

  void _pick() {
    var contacts = _poolCache ?? ContactDataStore.contacts;
    if (contacts.isEmpty) {
      _showToast(t('还没有联系人，去管理页添加吧！'));
      return;
    }
    // 逾期优先：有逾期的人时只从逾期者里随机
    final overdue = contacts.where((c) => c.isOverdue).toList();
    var pool = overdue.isNotEmpty ? overdue : contacts;
    // 避免近期重复：排除最近联系过的人（只剩 1 人时不排除）
    if (ContactDataStore.avoidRecent && pool.length > 1) {
      final contacted = pool.where((c) => c.lastContact != null).toList();
      if (contacted.isNotEmpty) {
        var mostRecent = contacted.first;
        for (final c in contacted) {
          if (c.lastContact!.isAfter(mostRecent.lastContact!)) {
            mostRecent = c;
          }
        }
        final rest = pool.where((c) => c != mostRecent).toList();
        if (rest.isNotEmpty) pool = rest;
      }
    }
    setState(() => _picked = ContactDataStore.pickFrom(pool));
  }

  void _checkIn() {
    if (_picked == null) return;
    ContactDataStore.checkIn(_picked!);
    setState(() {});
    _showToast(t('已联系 ${_picked!.name}，下次提醒：${_picked!.frequency.label}后', 'Contacted ${_picked!.name}. Next: ${_picked!.frequency.label}'));
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overdueCount =
        ContactDataStore.contacts.where((c) => c.isOverdue).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('今天联系谁')),
        centerTitle: true,
        toolbarHeight: 44,
        actions: [
          SchemeSwitcherButton(
              appId: 'contact', onSwitched: () => ContactDataStore.load()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 概览条
          Card(
            color: overdueCount > 0
                ? Theme.of(context).colorScheme.primary.withAlpha(12)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    overdueCount > 0
                        ? Icons.notifications_active
                        : Icons.thumb_up_alt_outlined,
                    size: 20,
                    color: overdueCount > 0
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      overdueCount > 0
                          ? t('有 $overdueCount 位朋友该联系了', '$overdueCount friends are due for a call')
                          : t('联系得很勤，继续保持！'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildResultCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.phone_in_talk, size: 24),
              label: Text(t('今天该联系谁？'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 4,
              ),
            ),
          ),
          if (_picked != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _checkIn,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text(t('已联系，打卡')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pick,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(t('换一个')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => showAddToPlanDialog(
                context,
                type: PlanType.contact,
                title: t('联系 ${_picked!.name}', 'Contact ${_picked!.name}'),
                emoji: _picked!.emoji,
              ),
              icon: const Icon(Icons.event_note, size: 18),
              label: Text(t('加入计划')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    if (_picked == null) {
      return Card(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Text('📞', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(t('点击下方按钮\n随机提醒一位该联系的朋友'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
    }

    final c = _picked!;
    final days = c.daysSinceContact;
    final overdue = c.overdueDays;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ItemImage(imagePath: c.imagePath, emoji: c.emoji, size: 120),
            const SizedBox(height: 8),
            Text(c.name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (c.relation.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(c.relation,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ],
            const SizedBox(height: 12),
            // 联系方式（可点击：拨号/邮件/复制）
            if (c.contacts.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: c.contacts.map((m) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ContactActions.perform(context, m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('${m.type.icon} ${m.value}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(t('约定 ${c.frequency.label}联系', 'Plan: ${c.frequency.label}'),
                      style:
                          TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: (overdue > 0 ? Colors.red : Colors.green).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    c.lastContact == null
                        ? t('还没联系过')
                        : overdue > 0
                            ? t('已逾期 $overdue 天', '$overdue days overdue')
                            : t('距上次联系 $days 天', '$days days since last contact'),
                    style: TextStyle(
                      fontSize: 13,
                      color: overdue > 0 ? Colors.red[700] : Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
