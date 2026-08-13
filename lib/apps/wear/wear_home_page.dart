import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/image_helper.dart';
import '../../core/language.dart';
import '../../core/season.dart';
import '../../core/theme.dart';
import '../../core/plan_store.dart';
import '../../core/widgets/add_to_plan_dialog.dart';
import '../../core/scheme_store.dart';
import '../../core/widgets/candidates_bar.dart';
import '../../core/widgets/date_selector.dart';
import '../../core/widgets/scheme_switcher.dart';
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
  WearGender _selectedGender = WearGender.unisex;
  WearGroup _selectedGroup = WearGroup.all;
  WearStyle _selectedStyle = WearStyle.all;
  int? _temperature; // null = 不限温度

  OutfitItem? _picked;

  // 备选列表（最近5 次 roll）
  final List<OutfitItem> _candidates = [];
  bool _isPicking = false;

  // 老虎机状态
  bool _rolling = false;
  List<OutfitItem> _rollItems = [];
  int _finalRollIndex = 0;
  FixedExtentScrollController? _wheelController;

  /// 随机池缓存（多方案合并），null = 用当前方案内存数据
  List<OutfitItem>? _poolCache;

  @override
  void initState() {
    super.initState();
    SchemeStore.notifier.addListener(_onSchemeChanged);
    _reloadAfterSwitch();
    _loadPrefs();
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value == 'wear') _reloadAfterSwitch();
  }

  /// 切换方案后：先加载新方案数据，再刷新随机池缓存，清空旧选中结果
  Future<void> _reloadAfterSwitch() async {
    await WearDataStore.load();
    final pool = await WearDataStore.loadRandomPool();
    if (mounted) {
      setState(() {
        _poolCache = pool;
        _picked = null;
        _candidates.clear();
      });
    }
  }

  /// 记忆性别/人群偏好
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedGender = WearGenderExt.fromString(
          prefs.getString('wear_gender') ?? 'unisex');
      _selectedGroup =
          WearGroupExt.fromString(prefs.getString('wear_group') ?? 'all');
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('wear_gender', _selectedGender.name);
    prefs.setString('wear_group', _selectedGroup.name);
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

    var pool = WearDataStore.getFilteredOutfits(
        scene: _selectedScene,
        gender: _selectedGender,
        group: _selectedGroup,
        style: _selectedStyle,
        temperature: _temperature,
        pool: _poolCache);
    if (WearDataStore.avoidRecent) {
      final recent = WearDataStore.getRecentOutfitNames();
      if (pool.any((o) => !recent.contains(o.name))) {
        pool = pool.where((o) => !recent.contains(o.name)).toList();
      }
    }
    if (pool.isEmpty) {
      _showToast(t('当前条件下没有穿搭，试试放宽温度或场景'));
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
        _pushCandidate();
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

  void _selectCandidate(OutfitItem item) {
    setState(() => _picked = item);
  }
  void _swap() {
    if (_isPicking || _picked == null) return;
    final pool = WearDataStore.getFilteredOutfits(
        scene: _selectedScene,
        gender: _selectedGender,
        group: _selectedGroup,
        style: _selectedStyle,
        temperature: _temperature,
        pool: _poolCache);
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _picked?.name) {
      _showToast(t('当前条件下就这一套啦'));
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
        title: Text(t('今天穿什么')),
        centerTitle: true,
        toolbarHeight: 44,
        actions: [
          SchemeSwitcherButton(
              appId: 'wear', onSwitched: () => WearDataStore.load()),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 目标日期
          TargetDateSelector(onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          _buildSectionTitle(
              t('穿什么'), t('${targetSeason.label}季', targetSeason.label)),
          const SizedBox(height: 8),
          _buildSceneSelector(),
          const SizedBox(height: 8),
          _buildGenderSelector(),
          const SizedBox(height: 8),
          _buildGroupSelector(),
          const SizedBox(height: 8),
          _buildStyleSelector(),
          const SizedBox(height: 8),
          _buildTempSelector(),
          const SizedBox(height: 16),
          _buildResultCard(),
          const SizedBox(height: 16),

          // 备选列表（最近几次 roll）
          if (!_rolling && _candidates.isNotEmpty) ...[
            CandidatesBar<OutfitItem>(
              items: _candidates,
              selected: _candidates.isNotEmpty ? _candidates.first : null,
              emojiOf: (p) => p.emoji,
              nameOf: (p) => p.name,
              onSelect: _selectCandidate,
            ),
            const SizedBox(height: 16),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.checkroom, size: 24),
              label: Text(_isPicking ? t('正在选...') : t('随机搭配一套！'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                disabledBackgroundColor: Theme.of(context).colorScheme.primaryLight,
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
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
              label: Text(s.label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedScene = s;
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

  /// 性别选择（记忆偏好）
  Widget _buildGenderSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: WearGender.values.map((g) {
          final isSelected = _selectedGender == g;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(
                switch (g) {
                  WearGender.male => Icons.male,
                  WearGender.female => Icons.female,
                  WearGender.unisex => Icons.accessibility_new,
                },
                size: 14,
                // 未选中按性别配色（男蓝/女粉/通用灰），不再用主题色
                color: isSelected
                    ? Colors.white
                    : switch (g) {
                        WearGender.male => Colors.blue,
                        WearGender.female => Colors.pink,
                        WearGender.unisex => Colors.grey,
                      },
              ),
              label: Text(g.label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedGender = g;
                        _picked = null;
                        _savePrefs();
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

  /// 人群选择（记忆偏好）
  Widget _buildGroupSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: WearGroup.values.map((g) {
          final isSelected = _selectedGroup == g;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(g.label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedGroup = g;
                        _picked = null;
                        _savePrefs();
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

  /// 风格选择
  Widget _buildStyleSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: WearStyle.values.map((s) {
          final isSelected = _selectedStyle == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s.label, style: const TextStyle(fontSize: 12)),
              visualDensity: VisualDensity.compact,
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedStyle = s;
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

  /// 温度选择：可选，填了按区间过滤
  Widget _buildTempSelector() {
    return Row(
      children: [
        Text(t('今天温度'),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline, size: 20),
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
          _temperature == null ? t('不限') : '$_temperature°C',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline, size: 20),
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
        const Spacer(),
        TextButton(
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          onPressed: _isPicking
              ? null
              : () => setState(() {
                    _temperature = null;
                    _picked = null;
                  }),
          child: Text(t('清除')),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    if (_rolling) {
      return _buildSlotMachine();
    }
    if (_picked == null) {
      return Card(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              const Text('🤔', style: TextStyle(fontSize: 44)),
              const SizedBox(height: 8),
              Text(t('选好条件，点下方按钮'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
        ),
      );
    }

    final tags = <String>[
      if (_picked!.seasons.isNotEmpty)
        t('${_picked!.seasons.map((s) => s.label).join('/')}季',
            _picked!.seasons.map((s) => s.label).join('/'))
      else
        t('四季通用'),
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
                '${_picked!.scene.label} · ${tags.join(' · ')}',
                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => showAddToPlanDialog(
                  context,
                  type: PlanType.wear,
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
                label: t('穿搭'),
                items: _rollItems,
                controller: _wheelController,
                emojiOf: (o) => o.emoji,
                nameOf: (o) => o.name,
                // Icon 组件颜色绝对可控，规避字体/emoji 渲染覆盖
                badgeBuilder: (o) => switch (o.gender) {
                  WearGender.male =>
                    const Icon(Icons.male, size: 12, color: Colors.blue),
                  WearGender.female =>
                    const Icon(Icons.female, size: 12, color: Colors.pink),
                  WearGender.unisex =>
                    Text(t('通用'),
                        style: TextStyle(
                            fontSize: 9, color: Colors.grey[600])),
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
