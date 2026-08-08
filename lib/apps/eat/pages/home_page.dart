import 'package:flutter/material.dart';
import '../../../core/image_helper.dart';
import '../../../core/season.dart' as core_season;
import '../../../core/theme.dart';
import '../../../core/widgets/date_selector.dart';
import '../../../core/widgets/slot_machine.dart';
import '../models/food_item.dart';
import '../data/data_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  MealTime _selectedMeal = MealTime.all;
  CookMode _selectedMode = CookMode.all;
  bool _wantDrink = false;

  FoodItem? _pickedDish;
  FoodItem? _pickedStaple;
  FoodItem? _pickedDrink;
  bool _isPicking = false;

  // 老虎机滚动状态
  bool _rolling = false;
  List<FoodItem> _dishRollItems = [];
  int _dishFinalIndex = 0;
  List<FoodItem> _stapleRollItems = [];
  int _stapleFinalIndex = 0;
  bool _hasStapleReel = false;
  List<FoodItem> _drinkRollItems = [];
  int _drinkFinalIndex = 0;
  bool _hasDrinkReel = false;
  FixedExtentScrollController? _dishWheelController;
  FixedExtentScrollController? _stapleWheelController;
  FixedExtentScrollController? _drinkWheelController;

  @override
  void dispose() {
    _dishWheelController?.dispose();
    _stapleWheelController?.dispose();
    _drinkWheelController?.dispose();
    super.dispose();
  }

  void _pick() {
    if (_isPicking) return;
    setState(() => _isPicking = true);

    var dishPool = DataStore.getFilteredDishes(mealTime: _selectedMeal, cookMode: _selectedMode);
    
    if (DataStore.settings.avoidRecent) {
      final recent = DataStore.getRecentDishNames();
      if (dishPool.any((d) => !recent.contains(d.name))) {
        dishPool = dishPool.where((d) => !recent.contains(d.name)).toList();
      }
    }

    if (dishPool.isEmpty) {
      dishPool = DataStore.getFilteredDishes(mealTime: _selectedMeal, cookMode: _selectedMode);
      if (dishPool.isEmpty) {
        _showToast('当前条件下没有菜品，去管理页添加吧！');
        setState(() => _isPicking = false);
        return;
      }
    }

    // 选定最终结果（保留原逻辑）
    final selectedDish = DataStore.pickFrom(dishPool,
        seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
    FoodItem? selectedStaple;
    FoodItem? selectedDrink;
    var staplePool = <FoodItem>[];
    var drinkPool = <FoodItem>[];
    if (_selectedMode == CookMode.cook) {
      staplePool = DataStore.getFilteredStaples(mealTime: _selectedMeal);
      if (staplePool.isNotEmpty) {
        if (DataStore.settings.avoidRecent) {
          final recent = DataStore.getRecentStapleNames();
          final filtered = staplePool.where((s) => !recent.contains(s.name)).toList();
          if (filtered.isNotEmpty) {
            selectedStaple = DataStore.pickFrom(filtered,
                seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
          } else {
            selectedStaple = DataStore.pickFrom(staplePool,
                seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
          }
        } else {
          selectedStaple = DataStore.pickFrom(staplePool,
              seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
        }
      }
    }

    if (_wantDrink) {
      drinkPool = DataStore.getFilteredDrinks(mealTime: _selectedMeal);
      if (drinkPool.isNotEmpty) {
        if (DataStore.settings.avoidRecent) {
          final recent = DataStore.getRecentDrinkNames();
          final filtered = drinkPool.where((d) => !recent.contains(d.name)).toList();
          if (filtered.isNotEmpty) {
            drinkPool = filtered;
          }
        }
        if (drinkPool.isNotEmpty) {
          selectedDrink = drinkPool[DateTime.now().microsecondsSinceEpoch % drinkPool.length];
        }
      }
    }

    DataStore.addHistory(HistoryRecord(
      dishName: selectedDish.name,
      stapleName: selectedStaple?.name,
      drinkName: selectedDrink?.name,
      dishEmoji: selectedDish.emoji,
      stapleEmoji: selectedStaple?.emoji,
      drinkEmoji: selectedDrink?.emoji,
      date: DateTime.now(),
      mealTime: _selectedMeal,
      cookMode: _selectedMode,
    ));

    // 只有一个候选且无主食/饮品时，跳过无意义的滚动直接出结果
    final skipRoll = dishPool.length <= 1 && selectedStaple == null && selectedDrink == null;
    if (skipRoll) {
      setState(() {
        _pickedDish = selectedDish;
        _pickedStaple = selectedStaple;
        _pickedDrink = selectedDrink;
        _isPicking = false;
      });
      return;
    }

    // 老虎机多列滚轮：菜 / 主食 / 饮品 各一列，复制候选池保证滚动距离，
    // 提前锁定各列最终项，滚动约 2 秒依次减速定格。
    final (dishItems, dishFinal) = _buildRollData(dishPool, dishPool.indexOf(selectedDish));
    var stapleData = (<FoodItem>[], 0);
    if (selectedStaple != null) {
      stapleData = _buildRollData(staplePool, staplePool.indexOf(selectedStaple));
    }
    var drinkData = (<FoodItem>[], 0);
    if (selectedDrink != null) {
      drinkData = _buildRollData(drinkPool, drinkPool.indexOf(selectedDrink));
    }

    _dishWheelController?.dispose();
    _stapleWheelController?.dispose();
    _drinkWheelController?.dispose();

    setState(() {
      _rolling = true;
      _dishRollItems = dishItems;
      _dishFinalIndex = dishFinal;
      _hasStapleReel = selectedStaple != null;
      _stapleRollItems = stapleData.$1;
      _stapleFinalIndex = stapleData.$2;
      _hasDrinkReel = selectedDrink != null;
      _drinkRollItems = drinkData.$1;
      _drinkFinalIndex = drinkData.$2;
      _dishWheelController = FixedExtentScrollController();
      _stapleWheelController = _hasStapleReel ? FixedExtentScrollController() : null;
      _drinkWheelController = _hasDrinkReel ? FixedExtentScrollController() : null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final futures = <Future<void>>[];
      if (_dishWheelController != null) {
        futures.add(_dishWheelController!.animateToItem(_dishFinalIndex,
            duration: const Duration(milliseconds: 2000), curve: Curves.easeOutCubic));
      }
      if (_stapleWheelController != null) {
        futures.add(_stapleWheelController!.animateToItem(_stapleFinalIndex,
            duration: const Duration(milliseconds: 1650), curve: Curves.easeOutCubic));
      }
      if (_drinkWheelController != null) {
        futures.add(_drinkWheelController!.animateToItem(_drinkFinalIndex,
            duration: const Duration(milliseconds: 1350), curve: Curves.easeOutCubic));
      }
      Future.wait(futures).whenComplete(() async {
        // 定格后停留片刻，让用户看清选中组合
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        final dishCtrl = _dishWheelController;
        final stapleCtrl = _stapleWheelController;
        final drinkCtrl = _drinkWheelController;
        _dishWheelController = null;
        _stapleWheelController = null;
        _drinkWheelController = null;
        dishCtrl?.dispose();
        stapleCtrl?.dispose();
        drinkCtrl?.dispose();
        setState(() {
          _rolling = false;
          _pickedDish = selectedDish;
          _pickedStaple = selectedStaple;
          _pickedDrink = selectedDrink;
          _isPicking = false;
        });
      });
    });
  }

  /// 点击菜名：换一道菜（遵守筛选/避免近期/季节，尽量避开当前菜）
  void _swapDish() {
    if (_isPicking) return;
    var pool = DataStore.getFilteredDishes(
        mealTime: _selectedMeal, cookMode: _selectedMode);
    if (DataStore.settings.avoidRecent) {
      final recent = DataStore.getRecentDishNames();
      if (pool.any((d) => !recent.contains(d.name))) {
        pool = pool.where((d) => !recent.contains(d.name)).toList();
      }
    }
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _pickedDish?.name) {
      _showToast('当前条件下就这一道菜啦');
      return;
    }
    var next = DataStore.pickFrom(pool,
        seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
    var tries = 0;
    while (next.name == _pickedDish?.name && pool.length > 1 && tries < 5) {
      next = DataStore.pickFrom(pool,
          seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
      tries++;
    }
    // 兜底：重试后仍相同则确定性换到下一道，保证一定不同
    if (next.name == _pickedDish?.name && pool.length > 1) {
      final idx = pool.indexOf(next);
      next = pool[(idx + 1) % pool.length];
    }
    setState(() => _pickedDish = next);
  }

  /// 点击主食按钮：换一个主食（不写历史，仅刷新展示）
  void _swapStaple() {
    if (_isPicking) return;
    final pool = DataStore.getFilteredStaples(mealTime: _selectedMeal);
    if (pool.isEmpty) return;
    if (pool.length == 1 && pool.first.name == _pickedStaple?.name) {
      _showToast('主食就这一样啦');
      return;
    }
    var next = DataStore.pickFrom(pool,
        seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
    var tries = 0;
    while (next.name == _pickedStaple?.name && pool.length > 1 && tries < 5) {
      next = DataStore.pickFrom(pool,
          seasonPriority: DataStore.settings.seasonRecommend,
            season: core_season.targetSeason);
      tries++;
    }
    if (next.name == _pickedStaple?.name && pool.length > 1) {
      final idx = pool.indexOf(next);
      next = pool[(idx + 1) % pool.length];
    }
    setState(() => _pickedStaple = next);
  }

  /// 点击饮品按钮：换一杯饮品（不写历史，仅刷新展示）
  void _swapDrink() {
    if (_isPicking) return;
    final pool = DataStore.getFilteredDrinks(mealTime: _selectedMeal);
    if (pool.isEmpty) return;
    final next = pool[DateTime.now().microsecondsSinceEpoch % pool.length];
    setState(() => _pickedDrink = next);
  }

  /// 构建一列滚轮数据：把候选池复制多份，返回（滚轮内容, 目标项下标）。
  ///
  /// 滚轮定格时正中央的项 = items[finalIndex] = pool[finalIndex % n]，
  /// 因此滚动距离必须取 n 的整数倍，再叠加目标下标，才能保证
  /// 定格项与选中项一致（否则会差 distance % n 位）。
  (List<FoodItem>, int) _buildRollData(List<FoodItem> pool, int targetIndex) {
    final n = pool.length;
    if (n == 0) return (<FoodItem>[], 0);
    final distance = 12 + DateTime.now().microsecondsSinceEpoch % 9;
    final spinBase = distance + (n - distance % n) % n;
    final repeats = ((spinBase + n * 2) / n).ceil();
    final items = List<FoodItem>.generate(repeats * n, (i) => pool[i % n]);
    return (items, spinBase + targetIndex);
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('今天吃什么'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 目标日期
          _buildSectionTitle('吃哪天的', '选择日期（影响应季推荐）'),
          const SizedBox(height: 8),
          TargetDateSelector(onChanged: () => setState(() {})),
          const SizedBox(height: 16),

          // Meal time selector
          _buildSectionTitle('吃什么', '选择餐段'),
          const SizedBox(height: 8),
          _buildMealSelector(),
          const SizedBox(height: 20),

          // Cook mode selector
          _buildSectionTitle('怎么吃', '选择方式'),
          const SizedBox(height: 8),
          _buildModeSelector(),
          const SizedBox(height: 16),

          // Drink toggle
          Card(
            child: SwitchListTile(
              secondary: Icon(Icons.local_drink, color: Theme.of(context).colorScheme.primary),
              title: const Text('想喝饮品'),
              subtitle: const Text('开启后随机推荐一杯饮品'),
              value: _wantDrink,
              onChanged: _isPicking
                  ? null
                  : (v) => setState(() {
                        _wantDrink = v;
                        _pickedDish = null;
                        _pickedStaple = null;
                        _pickedDrink = null;
                      }),
            ),
          ),
          const SizedBox(height: 24),

          // Result card
          _buildResultCard(theme),
          const SizedBox(height: 20),

          // Pick button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isPicking ? null : _pick,
              icon: const Icon(Icons.casino, size: 24),
              label: Text(_isPicking ? '正在选...' : '随机选一个！',
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
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildMealSelector() {
    const meals = [MealTime.all, MealTime.breakfast, MealTime.lunch, MealTime.dinner];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: meals.map((m) {
          final isSelected = _selectedMeal == m;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(m.label),
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedMeal = m;
                        _pickedDish = null;
                        _pickedStaple = null;
                        _pickedDrink = null;
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

  Widget _buildModeSelector() {
    const modes = [CookMode.all, CookMode.takeout, CookMode.cook, CookMode.eatOut];
    final icons = {
      CookMode.all: Icons.shuffle,
      CookMode.takeout: Icons.delivery_dining,
      CookMode.cook: Icons.kitchen,
      CookMode.eatOut: Icons.restaurant,
    };
    return Row(
      children: modes.map((m) {
        final isSelected = _selectedMode == m;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[m], size: 20, color: isSelected ? Colors.white : null),
                  Text(m.label, style: const TextStyle(fontSize: 12)),
                ],
              ),
              selected: isSelected,
              onSelected: _isPicking
                  ? null
                  : (_) => setState(() {
                        _selectedMode = m;
                        _pickedDish = null;
                        _pickedStaple = null;
                        _pickedDrink = null;
                      }),
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultCard(ThemeData theme) {
    if (_rolling) {
      return _buildSlotMachine(theme);
    }

    if (_pickedDish == null) {
      return Card(
        child: Container(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Text('🤔', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text('选择餐段和方式\n点击下方按钮开始', 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
    }

    final isCook = _selectedMode == CookMode.cook;

    return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 菜名（可点击换一道）
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _swapDish,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    children: [
                      ItemImage(imagePath: _pickedDish!.imagePath, emoji: _pickedDish!.emoji, size: 120),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_pickedDish!.name,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Icon(Icons.refresh, size: 18, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_pickedDish!.seasons.contains(core_season.targetSeason)) ...[
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍃', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Text('应季',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.primaryDark,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${_selectedMeal == MealTime.all ? '通用' : _selectedMeal.label} · ${_selectedMode == CookMode.all ? '不限方式' : _selectedMode.label}',
                      style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                  ),
                ],
              ),

              // Ingredients for cook mode
              if (isCook && _pickedDish!.ingredients.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildIngredientsList(_pickedDish!.ingredients, '菜品原料'),
              ],

              // Staple food for cook mode（可点击换一个）
              if (isCook && _pickedStaple != null) ...[
                const Divider(height: 24),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _swapStaple,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_pickedStaple!.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 8),
                          Text('搭配 ${_pickedStaple!.name}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          Icon(Icons.refresh, size: 18, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_pickedStaple!.ingredients.isNotEmpty)
                  _buildIngredientsList(_pickedStaple!.ingredients, '主食原料'),
              ],

              // Drink（可点击换一个）
              if (_pickedDrink != null) ...[
                const Divider(height: 24),
                Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _swapDrink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4FBF).withAlpha(18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF6C4FBF).withAlpha(80)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_pickedDrink!.emoji,
                              style: const TextStyle(fontSize: 28)),
                          const SizedBox(width: 8),
                          Text('随杯 ${_pickedDrink!.name}',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          const Icon(Icons.refresh, size: 18, color: Color(0xFF6C4FBF)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }

  /// 老虎机多列滚轮视图：菜/主食/饮品各一列，同时滚动依次减速定格。
  Widget _buildSlotMachine(ThemeData theme) {
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SlotReel(
                    label: '菜',
                    items: _dishRollItems,
                    controller: _dishWheelController,
                    emojiOf: (d) => d.displayEmoji,
                    nameOf: (d) => d.name,
                  ),
                  if (_hasStapleReel)
                    SlotReel(
                      label: '主食',
                      items: _stapleRollItems,
                      controller: _stapleWheelController,
                      emojiOf: (d) => d.displayEmoji,
                      nameOf: (d) => d.name,
                    ),
                  if (_hasDrinkReel)
                    SlotReel(
                      label: '饮品',
                      items: _drinkRollItems,
                      controller: _drinkWheelController,
                      emojiOf: (d) => d.displayEmoji,
                      nameOf: (d) => d.name,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIngredientsList(List<String> ingredients, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ingredients.map((ing) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(60)),
              ),
              child: Text(ing, style: const TextStyle(fontSize: 13)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}
