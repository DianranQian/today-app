import 'package:flutter/material.dart';
import '../../core/language.dart';
import '../../core/theme.dart';
import '../../core/plan_store.dart';
import '../../core/widgets/add_to_plan_dialog.dart';
import '../../core/scheme_store.dart';
import '../../core/widgets/candidates_bar.dart';
import '../../core/widgets/scheme_switcher.dart';
import '../../core/widgets/slot_machine.dart';
import '../../core/image_helper.dart';
import 'go_models.dart';
import 'go_data_store.dart';

class GoHomePage extends StatefulWidget {
  const GoHomePage({super.key});

  @override
  State<GoHomePage> createState() => _GoHomePageState();
}

class _GoHomePageState extends State<GoHomePage> {
  PlaceType _selectedType = PlaceType.all;
  int? _maxPriceTier; // 预算上限（1-3），null=不限

  PlaceItem? _picked;

  // 备选列表（最近5 次 roll）
  final List<PlaceItem> _candidates = [];
  bool _isPicking = false;

  // 老虎机状态
  bool _rolling = false;
  List<PlaceItem> _rollItems = [];
  int _finalRollIndex = 0;
  FixedExtentScrollController? _wheelController;

  /// 随机池缓存（多方案合并），null = 用当前方案内存数据
  List<PlaceItem>? _poolCache;

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onSchemeChanged);
    _reloadAfterSwitch();
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value == 'go') _reloadAfterSwitch();
  }

  /// 切换方案后：先加载新方案数据，再刷新随机池缓存，清空旧选中结果
  Future<void> _reloadAfterSwitch() async {
    await GoDataStore.load();
    final pool = await GoDataStore.loadRandomPool();
    if (mounted) {
      setState(() {
        _poolCache = pool;
        _picked = null;
        _candidates.clear();
      });
    }
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onSchemeChanged);
    _wheelController?.dispose();
    super.dispose();
  }

  void _pick() {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    var pool = GoDataStore.getFilteredPlaces(
        type: _selectedType, pool: _poolCache);
    if (_maxPriceTier != null) {
      pool = pool.where((p) => p.priceTier <= _maxPriceTier!).toList();
    }
    if (GoDataStore.avoidRecent) {
      final recent = GoDataStore.getRecentPlaceNames();
      if (pool.any((p) => !recent.contains(p.name))) {
        pool = pool.where((p) => !recent.contains(p.name)).toList();
      }
    }
    if (pool.isEmpty) {
      _showToast(t('当前类型下没有去处，去管理页添加吧！'));
      setState(() => _isPicking = false);
      return;
    }

    final selected = GoDataStore.pickFrom(pool);
    GoDataStore.addHistory(GoHistoryRecord(
      placeName: selected.name,
      placeEmoji: selected.emoji,
      date: DateTime.now(),
    ));

    final (items, finalIndex) = _buildRollData(pool, pool.indexOf(selected));

    _wheelController?.dispose();
    setState(() {
      _rolling = true;
      _rollItems = items;
      _finalRollIndex = finalIndex;
      _wheelController = FixedExtentScrollController();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _wheelController == null) return;
      _wheelController!
          .animateToItem(
            _finalRollIndex,
            duration: const Duration(milliseconds: 2000),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() async {
        // 定格后停留片刻
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        final ctrl = _wheelController;
        _wheelController = null;
        ctrl?.dispose();
        setState(() {
          _rolling = false;
          _picked = selected;
          _isPicking = false;
        });
        _pushCandidate();
      });
    });
  }

  /// 构建滚轮数据：复制候选池多份，滚动距离取候选数整数倍，保证定格项=选中项
  (List<PlaceItem>, int) _buildRollData(List<PlaceItem> pool, int targetIndex) {
    final n = pool.length;
    if (n == 0) return (<PlaceItem>[], 0);
    final distance = 12 + DateTime.now().microsecondsSinceEpoch % 9;
    final spinBase = distance + (n - distance % n) % n;
    final repeats = ((spinBase + n * 2) / n).ceil();
    final items = List<PlaceItem>.generate(repeats * n, (i) => pool[i % n]);
    return (items, spinBase + targetIndex);
  }

  /// 加入备选（名称去重，最多 5 条）
  void _pushCandidate() {
    final p = _picked;
    if (p == null) return;
    _candidates.removeWhere((x) => x.name == p.name);
    _candidates.insert(0, p);
    if (_candidates.length > 5) {
      _candidates.removeRange(5, _candidates.length);
    }
  }

  void _selectCandidate(PlaceItem item) {
    setState(() => _picked = item);
  }
  void _swap() {
    if (_isPicking || _picked == null) return;
    var pool = GoDataStore.getFilteredPlaces(
        type: _selectedType, pool: _poolCache);
    if (_maxPriceTier != null) {
      pool = pool.where((p) => p.priceTier <= _maxPriceTier!).toList();
    }
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _picked?.name) {
      _showToast(t('当前条件下就这一个去处啦'));
      return;
    }
    var next = GoDataStore.pickFrom(pool);
    var tries = 0;
    while (next.name == _picked?.name && pool.length > 1 && tries < 5) {
      next = GoDataStore.pickFrom(pool);
      tries++;
    }
    if (next.name == _picked?.name && pool.length > 1) {
      final idx = pool.indexOf(next);
      next = pool[(idx + 1) % pool.length];
    }
    setState(() {
      _picked = next;
      if (_candidates.isNotEmpty) _candidates[0] = next;
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('今天去哪')),
        centerTitle: true,
        toolbarHeight: 44,
        actions: [
          SchemeSwitcherButton(
              appId: 'go', onSwitched: () => GoDataStore.load()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(t('去哪'), t('选择类型')),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 12),
          _buildBudgetSelector(),
          const SizedBox(height: 24),
          _buildResultCard(),
          const SizedBox(height: 16),

          // 备选列表（最近几次 roll）
          if (!_rolling && _candidates.isNotEmpty) ...[
            CandidatesBar<PlaceItem>(
              items: _candidates,
              selected: _candidates.isNotEmpty ? _candidates.first : null,
              emojiOf: (p) => p.emoji,
              nameOf: (p) => p.name,
              onSelect: _selectCandidate,
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.casino, size: 24),
              label: Text(_isPicking ? t('正在选...') : t('随机选一个！'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: Theme.of(context).colorScheme.primaryLight,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }


  /// 预算上限选择
  Widget _buildBudgetSelector() {
    final options = <int?, String>{
      null: t('不限'),
      1: t('¥ 低'),
      2: t('¥¥ 中'),
      3: t('¥¥¥ 高'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.entries.map((e) {
          final isSelected = _maxPriceTier == e.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _maxPriceTier = e.key;
                        _picked = null;
                      }),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypeSelector() {
    const types = [
      PlaceType.all, PlaceType.eat, PlaceType.shop, PlaceType.park,
      PlaceType.culture, PlaceType.sport, PlaceType.night,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((t) {
          final isSelected = _selectedType == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t.label),
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedType = t;
                        _picked = null;
                      }),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildResultCard() {
    if (_rolling) {
      return _buildSlotMachine();
    }
    if (_picked == null) {
      return Card(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Text('🤔', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(t('选择类型\n点击下方按钮开始'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _swap,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: [
                    ItemImage(imagePath: _picked!.imagePath, emoji: _picked!.emoji, size: 120),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_picked!.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Icon(Icons.refresh, size: 18, color: Theme.of(context).colorScheme.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_picked!.type.label} · ${_picked!.priceLabel}',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
              ),
            ),

            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => showAddToPlanDialog(
                context,
                type: PlanType.go,
                title: _picked!.name,
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
        ),
      ),
    );
  }

  /// 单列老虎机滚轮
  Widget _buildSlotMachine() {
    const wheelHeight = 176.0;

    return Column(
      children: [
        const RollingHint(),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: wheelHeight + 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SlotReel(
                    label: t('去处'),
                    items: _rollItems,
                    controller: _wheelController,
                    emojiOf: (p) => p.emoji,
                    nameOf: (p) => p.name,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
