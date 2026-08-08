import 'package:flutter/material.dart';
import '../../core/season.dart';
import '../../core/widgets/slot_machine.dart';
import 'wear_models.dart';
import 'wear_data_store.dart';

class WearHomePage extends StatefulWidget {
  const WearHomePage({super.key});

  @override
  State<WearHomePage> createState() => _WearHomePageState();
}

class _WearHomePageState extends State<WearHomePage> {
  WearScene _selectedScene = WearScene.all;
  int? _temperature; // null = 不限温度

  OutfitItem? _picked;
  bool _isPicking = false;

  // 老虎机状态
  bool _rolling = false;
  List<OutfitItem> _rollItems = [];
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

    var pool = WearDataStore.getFilteredOutfits(
        scene: _selectedScene, temperature: _temperature);
    final recent = WearDataStore.getRecentOutfitNames();
    if (pool.any((o) => !recent.contains(o.name))) {
      pool = pool.where((o) => !recent.contains(o.name)).toList();
    }
    if (pool.isEmpty) {
      _showToast('当前条件下没有穿搭，试试放宽温度或场景');
      setState(() => _isPicking = false);
      return;
    }

    final selected = WearDataStore.pickFrom(pool);
    WearDataStore.addHistory(WearHistoryRecord(
      outfitName: selected.name,
      outfitEmoji: selected.emoji,
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

  (List<OutfitItem>, int) _buildRollData(
      List<OutfitItem> pool, int targetIndex) {
    final n = pool.length;
    if (n == 0) return (<OutfitItem>[], 0);
    final distance = 12 + DateTime.now().microsecondsSinceEpoch % 9;
    final spinBase = distance + (n - distance % n) % n;
    final repeats = ((spinBase + n * 2) / n).ceil();
    final items = List<OutfitItem>.generate(repeats * n, (i) => pool[i % n]);
    return (items, spinBase + targetIndex);
  }

  void _swap() {
    if (_isPicking || _picked == null) return;
    final pool = WearDataStore.getFilteredOutfits(
        scene: _selectedScene, temperature: _temperature);
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _picked?.name) {
      _showToast('当前条件下就这一套啦');
      return;
    }
    var next = WearDataStore.pickFrom(pool);
    var tries = 0;
    while (next.name == _picked?.name && pool.length > 1 && tries < 5) {
      next = WearDataStore.pickFrom(pool);
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
        title: const Text('今天穿什么'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('穿什么', '选择场景 · 当前${currentSeason.label}季'),
          const SizedBox(height: 8),
          _buildSceneSelector(),
          const SizedBox(height: 12),
          _buildTempSelector(),
          const SizedBox(height: 24),
          _buildResultCard(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.checkroom, size: 24),
              label: Text(_isPicking ? '正在选...' : '随机搭配一套！',
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

  Widget _buildSceneSelector() {
    const scenes = [
      WearScene.all, WearScene.daily, WearScene.sport, WearScene.formal,
      WearScene.date, WearScene.commute,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenes.map((s) {
          final isSelected = _selectedScene == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s.label),
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedScene = s;
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

  /// 温度选择：可选，填了按区间过滤
  Widget _buildTempSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.thermostat, size: 18, color: Color(0xFFFF6B35)),
            const SizedBox(width: 8),
            const Text('今天温度', style: TextStyle(fontSize: 14)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _isPicking
                  ? null
                  : () => setState(() {
                        if (_temperature == null) {
                          _temperature = 20;
                        } else if (_temperature! > -20) {
                          _temperature = _temperature! - 1;
                        }
                        _picked = null;
                      }),
            ),
            Text(
              _temperature == null ? '不限' : '$_temperature°C',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _isPicking
                  ? null
                  : () => setState(() {
                        if (_temperature == null) {
                          _temperature = 20;
                        } else if (_temperature! < 45) {
                          _temperature = _temperature! + 1;
                        }
                        _picked = null;
                      }),
            ),
            TextButton(
              onPressed: _isPicking
                  ? null
                  : () => setState(() {
                        _temperature = null;
                        _picked = null;
                      }),
              child: const Text('清除'),
            ),
          ],
        ),
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
              Text('选择场景（可选填温度）\n点击下方按钮开始',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
    }

    final tags = <String>[
      if (_picked!.seasons.isNotEmpty)
        '${_picked!.seasons.map((s) => s.label).join('/')}季'
      else
        '四季通用',
      if (_picked!.tempMin != null || _picked!.tempMax != null)
        '${_picked!.tempMin ?? '~'}~${_picked!.tempMax ?? '~'}°C',
    ];

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
                '${_picked!.scene.label} · ${tags.join(' · ')}',
                style: const TextStyle(fontSize: 13, color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                label: '穿搭',
                items: _rollItems,
                controller: _wheelController,
                emojiOf: (o) => o.emoji,
                nameOf: (o) => o.name,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
