import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/image_helper.dart';
import '../../../core/language.dart';
import '../../../core/scheme_store.dart';
import '../../../core/services/ai_service.dart';
import '../../../core/widgets/profile_dialog.dart';
import '../../../core/widgets/scheme_switcher.dart';
import '../models/food_item.dart';
import '../data/data_store.dart';

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _dishNameCtrl = TextEditingController();
  final _dishEmojiCtrl = TextEditingController();
  final _dishSearchCtrl = TextEditingController();
  MealTime _dishMeal = MealTime.all;
  CookMode _dishMode = CookMode.all;
  final _dishIngredientsCtrl = TextEditingController();
  String? _dishImagePath;

  final _stapleNameCtrl = TextEditingController();
  final _stapleEmojiCtrl = TextEditingController();
  final _stapleSearchCtrl = TextEditingController();
  MealTime _stapleMeal = MealTime.all;
  final _stapleIngredientsCtrl = TextEditingController();
  String? _stapleImagePath;

  final _drinkNameCtrl = TextEditingController();
  final _drinkEmojiCtrl = TextEditingController();
  final _drinkSearchCtrl = TextEditingController();
  MealTime _drinkMeal = MealTime.all;
  String? _drinkImagePath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    SchemeStore.notifier.addListener(_onSchemeChanged);
  }

  void _onSchemeChanged() {
    if (SchemeStore.notifier.value != 'eat') return;
    DataStore.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    SchemeStore.notifier.removeListener(_onSchemeChanged);
    _tabController.dispose();
    _dishNameCtrl.dispose();
    _dishEmojiCtrl.dispose();
    _dishSearchCtrl.dispose();
    _dishIngredientsCtrl.dispose();
    _stapleNameCtrl.dispose();
    _stapleEmojiCtrl.dispose();
    _stapleSearchCtrl.dispose();
    _stapleIngredientsCtrl.dispose();
    _drinkNameCtrl.dispose();
    _drinkEmojiCtrl.dispose();
    _drinkSearchCtrl.dispose();
    super.dispose();
  }

  void _addDish() {
    final name = _dishNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast(t('请输入菜名'));
      return;
    }
    if (DataStore.dishes.any((d) => d.name == name)) {
      _showToast(t('这道菜已经存在了'));
      return;
    }
    DataStore.dishes.add(FoodItem(
      name: name,
      emoji: _dishEmojiCtrl.text.trim().isNotEmpty ? _dishEmojiCtrl.text.trim() : '🍽️',
      mealTime: _dishMeal,
      cookMode: _dishMode,
      ingredients: _dishIngredientsCtrl.text
          .split(RegExp(r"[,，、\\s]+"))
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList(),
      imagePath: _dishImagePath,
    ));
    DataStore.save();
    _dishNameCtrl.clear();
    _dishEmojiCtrl.clear();
    _dishIngredientsCtrl.clear();
    _dishImagePath = null;
    setState(() {});
    _showToast(t('已添加 '));
  }

  void _addStaple() {
    final name = _stapleNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast(t('请输入主食名称'));
      return;
    }
    if (DataStore.staples.any((s) => s.name == name)) {
      _showToast(t('这个主食已经存在了'));
      return;
    }
    DataStore.staples.add(FoodItem(
      name: name,
      emoji: _stapleEmojiCtrl.text.trim().isNotEmpty ? _stapleEmojiCtrl.text.trim() : '🍚',
      mealTime: _stapleMeal,
      cookMode: CookMode.all,
      isStaple: true,
      ingredients: _stapleIngredientsCtrl.text
          .split(RegExp(r"[,，、\\s]+"))
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList(),
      imagePath: _stapleImagePath,
    ));
    DataStore.save();
    _stapleNameCtrl.clear();
    _stapleEmojiCtrl.clear();
    _stapleIngredientsCtrl.clear();
    _stapleImagePath = null;
    setState(() {});
    _showToast(t('已添加 '));
  }

  void _deleteDish(int index) {
    final name = DataStore.dishes[index].name;
    DataStore.dishes.removeAt(index);
    DataStore.save();
    setState(() {});
    _showToast(t('已删除 $name', 'Deleted $name'));
  }

  void _deleteStaple(int index) {
    final name = DataStore.staples[index].name;
    DataStore.staples.removeAt(index);
    DataStore.save();
    setState(() {});
    _showToast(t('已删除 $name', 'Deleted $name'));
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// 配置集：另存为 / 应用 / 导出 / AI 汇总
  Future<void> _openProfiles() async {
    await showProfileDialog(
      context,
      appId: 'eat',
      currentItems:
          DataStore.dishes.map((d) => d.toJson()).toList(),
      applyItems: (items) {
        setState(() {
          DataStore.dishes =
              items.map((e) => FoodItem.fromJson(e)).toList();
          DataStore.save();
        });
      },
      aiCurate: _aiCurateEat,
      exportBaseName: 'eat_dishes',
    );
  }

  /// AI 汇总：从当前菜库挑选一组适合周末的菜，新建「AI精选」方案入库并切换
  Future<String> _aiCurateEat() async {
    final names = DataStore.dishes.map((d) => d.name).toList();
    final raw = await AiService.chat(
      '你是家常菜谱策划。从给定的菜名列表中挑选 10 道适合周末在家做的菜，'
          '只输出 JSON 字符串数组，不要输出任何其他内容。',
      names.join('、'),
    );
    final picked = (jsonDecode(raw.trim()) as List).cast<String>();
    final items = DataStore.dishes
        .where((d) => picked.contains(d.name))
        .map((d) => d.toJson())
        .toList();
    if (items.isEmpty) {
      throw Exception(t('AI 返回内容无法匹配菜谱，请重试'));
    }
    final name = await SchemeStore.createWithData(
        'eat', t('AI精选', 'AI Picks'), 'dishes', items);
    await DataStore.load();
    return name;
  }

  /// 选图行：缩略图预览 + 选图/清除按钮
  Widget _buildImagePickerRow(String? imagePath, Future<void> Function() onPick,
      VoidCallback onClear) {
    return Row(
      children: [
        ItemImage(imagePath: imagePath, emoji: '🖼️', size: 48),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_photo_alternate, size: 18),
            label: Text(t('添加图片')),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withAlpha(70)),
            ),
          ),
        ),
        if (imagePath != null)
          IconButton(
            tooltip: t('清除图片'),
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onClear,
          ),
      ],
    );
  }

  Future<void> _pickDishImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _dishImagePath = p);
  }

  Future<void> _pickStapleImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _stapleImagePath = p);
  }

  Future<void> _pickDrinkImage() async {
    final p = await ImageHelper.pick(context);
    if (p != null) setState(() => _drinkImagePath = p);
  }

  Future<void> _importRecipes() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'txt'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    try {
      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        _showToast(t('无法读取文件内容'));
        return;
      }
      final text = DataStore.decodeFileBytes(bytes);
      final result = DataStore.importRecipes(text);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('导入结果')),
          content: Text(
            result.errors.isEmpty
                ? result.toString()
                : t('${result.toString()}\n\n以下条目有问题：\n${result.errors.take(5).join('\n')}',
                    '${result.toString()}\n\nSome entries have issues:\n${result.errors.take(5).join('\n')}'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('好的')),
            ),
          ],
        ),
      );
      setState(() {});
    } catch (e) {
      _showToast(t('导入失败：$e', 'Import failed: $e'));
    }
  }

  void _showFormatHelp() {
    const sample = '''
[
  {
    "name": "番茄炒蛋",
    "emoji": "🍅",
    "mealTime": "lunch",
    "cookMode": "cook",
    "ingredients": ["番茄", "鸡蛋", "葱"],
    "seasons": []
  }
]''';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('菜谱文件格式说明')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('文件为 JSON 数组，每道菜一个对象：')),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(sample, style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(height: 12),
              Text(t('字段说明：\n'
                  'name - 菜名（必填）\n'
                  'emoji - 图标，可省略\n'
                  'mealTime - breakfast/lunch/dinner/all\n'
                  'cookMode - takeout外卖/cook自己做/eatOut出去吃/all\n'
                  'ingredients - 原料列表\n'
                  'seasons - 季节 spring/summer/autumn/winter，空=四季通用\n'
                  'isStaple - true 则该条归入主食库\n'
                  'isDrink - true 则该条归入饮品库',
                  'Fields:\n'
                  'name - dish name (required)\n'
                  'emoji - icon, optional\n'
                  'mealTime - breakfast/lunch/dinner/all\n'
                  'cookMode - takeout/cook/eatOut/all\n'
                  'ingredients - list of ingredients\n'
                  'seasons - spring/summer/autumn/winter, empty = all seasons\n'
                  'isStaple - true moves it to the staple library\n'
                  'isDrink - true moves it to the drink library'),
                style: TextStyle(fontSize: 13, height: 1.6)),
              const SizedBox(height: 12),
              Text(t('小技巧：可以把上面示例发给 AI 助手，让它帮你按这个格式批量生成菜谱，'
                  '保存为 .json 文件后导入即可。重名的菜会自动跳过。文件支持 UTF-8 和 GBK 编码。',
                  'Tip: send the sample above to an AI assistant to batch-generate recipes in this format, '
                  'save as a .json file and import. Duplicate names are skipped automatically. '
                  'UTF-8 and GBK encodings are both supported.'),
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t('知道了')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('管理菜单')),
        actions: [
          SchemeSwitcherButton(
              appId: 'eat', onSwitched: () => DataStore.load()),
          IconButton(
            tooltip: t('配置集'),
            icon: const Icon(Icons.folder_copy_outlined),
            onPressed: _openProfiles,
          ),
          IconButton(
            tooltip: t('导入菜谱'),
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _importRecipes,
          ),
          IconButton(
            tooltip: t('菜谱格式说明'),
            icon: const Icon(Icons.help_outline),
            onPressed: _showFormatHelp,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: t('菜肴'), icon: const Icon(Icons.restaurant_menu)),
            Tab(text: t('主食'), icon: const Icon(Icons.rice_bowl)),
            Tab(text: t('饮品'), icon: const Icon(Icons.local_drink)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDishTab(),
          _buildStapleTab(),
          _buildDrinkTab(),
        ],
      ),
    );
  }

  // -------- Dish Tab --------
  Widget _buildDishTab() {
    final dishes = DataStore.search(_dishSearchCtrl.text);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('添加菜肴'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _dishNameCtrl,
                        decoration: InputDecoration(
                          labelText: t('菜名'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addDish(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _dishEmojiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Emoji',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        maxLength: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MealTime>(
                        value: _dishMeal,
                        decoration: InputDecoration(
                          labelText: t('适合餐段'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: MealTime.all, child: Text(MealTime.all.label)),
                          DropdownMenuItem(value: MealTime.breakfast, child: Text(MealTime.breakfast.label)),
                          DropdownMenuItem(value: MealTime.lunch, child: Text(MealTime.lunch.label)),
                          DropdownMenuItem(value: MealTime.dinner, child: Text(MealTime.dinner.label)),
                        ],
                        onChanged: (v) => setState(() => _dishMeal = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<CookMode>(
                        value: _dishMode,
                        decoration: InputDecoration(
                          labelText: t('适合方式'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(value: CookMode.all, child: Text(CookMode.all.label)),
                          DropdownMenuItem(value: CookMode.takeout, child: Text(CookMode.takeout.label)),
                          DropdownMenuItem(value: CookMode.cook, child: Text(CookMode.cook.label)),
                          DropdownMenuItem(value: CookMode.eatOut, child: Text(CookMode.eatOut.label)),
                        ],
                        onChanged: (v) => setState(() => _dishMode = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _dishIngredientsCtrl,
                  decoration: InputDecoration(
                    labelText: t('原料（用逗号分隔）'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildImagePickerRow(
                    _dishImagePath, _pickDishImage, () => setState(() => _dishImagePath = null)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addDish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('添加')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Search box
        TextField(
          controller: _dishSearchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: t('按菜名或食材搜索'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Dish list
        if (dishes.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(t('没有找到匹配的菜肴'), style: const TextStyle(color: Colors.grey)),
          ))
        else
          ...dishes.asMap().entries.map((entry) {
            final i = DataStore.dishes.indexOf(entry.value);
            final dish = entry.value;
            return Dismissible(
              key: ValueKey('dish__${dish.name}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteDish(i),
              child: ListTile(
                leading: ItemImage(imagePath: dish.imagePath, emoji: dish.emoji, size: 44),
                title: Text(dish.name),
                subtitle: const Text(' · '),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteDish(i),
                ),
              ),
            );
          }),
      ],
    );
  }

  // -------- Staple Tab --------
  Widget _buildStapleTab() {
    final staples = DataStore.searchStaples(_stapleSearchCtrl.text);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Add form
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('添加主食'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _stapleNameCtrl,
                        decoration: InputDecoration(
                          labelText: t('主食名称'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addStaple(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _stapleEmojiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Emoji',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        maxLength: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MealTime>(
                  value: _stapleMeal,
                  decoration: InputDecoration(
                    labelText: t('适合餐段'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: MealTime.all, child: Text(MealTime.all.label)),
                    DropdownMenuItem(value: MealTime.breakfast, child: Text(MealTime.breakfast.label)),
                    DropdownMenuItem(value: MealTime.lunch, child: Text(MealTime.lunch.label)),
                    DropdownMenuItem(value: MealTime.dinner, child: Text(MealTime.dinner.label)),
                  ],
                  onChanged: (v) => setState(() => _stapleMeal = v!),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _stapleIngredientsCtrl,
                  decoration: InputDecoration(
                    labelText: t('原料（用逗号分隔）'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                _buildImagePickerRow(
                    _stapleImagePath, _pickStapleImage, () => setState(() => _stapleImagePath = null)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addStaple,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('添加')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Search box
        TextField(
          controller: _stapleSearchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: t('按名称或食材搜索'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        // Staple list
        if (staples.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(t('没有找到匹配的主食'), style: const TextStyle(color: Colors.grey)),
          ))
        else
          ...staples.asMap().entries.map((entry) {
            final i = DataStore.staples.indexOf(entry.value);
            final staple = entry.value;
            return Dismissible(
              key: ValueKey('staple__${staple.name}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteStaple(i),
              child: ListTile(
                leading: ItemImage(imagePath: staple.imagePath, emoji: staple.emoji, size: 44),
                title: Text(staple.name),
                subtitle: Text(staple.mealTime.label),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteStaple(i),
                ),
              ),
            );
          }),
      ],
    );
  }

  // -------- Drink Tab --------
  void _addDrink() {
    final name = _drinkNameCtrl.text.trim();
    if (name.isEmpty) {
      _showToast(t('请输入饮品名称'));
      return;
    }
    if (DataStore.drinks.any((d) => d.name == name)) {
      _showToast(t('这个饮品已经存在了'));
      return;
    }
    DataStore.drinks.add(FoodItem(
      name: name,
      emoji: _drinkEmojiCtrl.text.trim().isNotEmpty ? _drinkEmojiCtrl.text.trim() : '🥤',
      mealTime: _drinkMeal,
      isDrink: true,
      imagePath: _drinkImagePath,
    ));
    DataStore.save();
    _drinkNameCtrl.clear();
    _drinkEmojiCtrl.clear();
    _drinkImagePath = null;
    setState(() {});
    _showToast(t('已添加 $name', 'Added $name'));
  }

  void _deleteDrink(int index) {
    final name = DataStore.drinks[index].name;
    DataStore.drinks.removeAt(index);
    DataStore.save();
    setState(() {});
    _showToast(t('已删除 $name', 'Deleted $name'));
  }

  Widget _buildDrinkTab() {
    final drinks = DataStore.searchDrinks(_drinkSearchCtrl.text);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('添加饮品'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _drinkNameCtrl,
                        decoration: InputDecoration(
                          labelText: t('饮品名称'),
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addDrink(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: _drinkEmojiCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Emoji',
                          border: OutlineInputBorder(),
                          isDense: true,
                          counterText: '',
                        ),
                        maxLength: 4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MealTime>(
                  value: _drinkMeal,
                  decoration: InputDecoration(
                    labelText: t('适合餐段'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(value: MealTime.all, child: Text(MealTime.all.label)),
                    DropdownMenuItem(value: MealTime.breakfast, child: Text(MealTime.breakfast.label)),
                    DropdownMenuItem(value: MealTime.lunch, child: Text(MealTime.lunch.label)),
                    DropdownMenuItem(value: MealTime.dinner, child: Text(MealTime.dinner.label)),
                  ],
                  onChanged: (v) => setState(() => _drinkMeal = v!),
                ),
                const SizedBox(height: 12),
                _buildImagePickerRow(
                    _drinkImagePath, _pickDrinkImage, () => setState(() => _drinkImagePath = null)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addDrink,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(t('添加')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _drinkSearchCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: t('按名称搜索'),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),

        if (drinks.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(t('没有找到匹配的饮品'), style: const TextStyle(color: Colors.grey)),
          ))
        else
          ...drinks.asMap().entries.map((entry) {
            final i = DataStore.drinks.indexOf(entry.value);
            final drink = entry.value;
            return Dismissible(
              key: ValueKey('drink__${drink.name}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                color: Colors.red,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => _deleteDrink(i),
              child: ListTile(
                leading: ItemImage(imagePath: drink.imagePath, emoji: drink.emoji, size: 44),
                title: Text(drink.name),
                subtitle: Text(drink.mealTime.label),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteDrink(i),
                ),
              ),
            );
          }),
      ],
    );
  }
}
