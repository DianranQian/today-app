import 'package:flutter/material.dart';
import '../../core/widgets/slot_machine.dart';
import 'go_models.dart';
import 'go_data_store.dart';

class GoHomePage extends StatefulWidget {
  const GoHomePage({super.key});

  @override
  State<GoHomePage> createState() => _GoHomePageState();
}

class _GoHomePageState extends State<GoHomePage> {
  PlaceType _selectedType = PlaceType.all;

  PlaceItem? _picked;
  bool _isPicking = false;

  // 老虎机状态
  bool _rolling = false;
  List<PlaceItem> _rollItems = [];
  int _finalRollIndex = 0;
  FixedExtentScrollController? _wheelController;

  @override
  void dispose() {
    _wheelController?.dispose();
    super.dispose();
  }

  void _pick() {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    var pool = GoDataStore.getFilteredPlaces(type: _selectedType);
    final recent = GoDataStore.getRecentPlaceNames();
    if (pool.any((p) => !recent.contains(p.name))) {
      pool = pool.where((p) => !recent.contains(p.name)).toList();
    }
    if (pool.isEmpty) {
      _showToast('当前类型下没有去处，去管理页添加吧！');
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

  void _swap() {
    if (_isPicking || _picked == null) return;
    final pool = GoDataStore.getFilteredPlaces(type: _selectedType);
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _picked?.name) {
      _showToast('当前条件下就这一个去处啦');
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
    setState(() => _picked = next);
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
        title: const Text('今天去哪'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('去哪', '选择类型'),
          const SizedBox(height: 8),
          _buildTypeSelector(),
          const SizedBox(height: 24),
          _buildResultCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.casino, size: 24),
              label: Text(_isPicking ? '正在选...' : '随机选一个！',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                disabledBackgroundColor: const Color(0xFFFF9A72),
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
              selectedColor: const Color(0xFFFF6B35),
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
              Text('选择类型\n点击下方按钮开始',
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
                    Text(_picked!.emoji, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_picked!.name,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        const Icon(Icons.refresh, size: 18, color: Color(0xFFFF6B35)),
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
                color: const Color(0xFFFF6B35).withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_picked!.type.label} · ${_picked!.priceLabel}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFFF6B35)),
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
              child: SlotReel(
                label: '去处',
                items: _rollItems,
                controller: _wheelController,
                emojiOf: (p) => p.emoji,
                nameOf: (p) => p.name,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
