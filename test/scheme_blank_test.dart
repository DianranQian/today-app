import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:today_app/apps/eat/data/data_store.dart';
import 'package:today_app/apps/eat/models/food_item.dart';
import 'package:today_app/apps/go/go_data_store.dart';
import 'package:today_app/apps/wear/wear_data_store.dart';
import 'package:today_app/core/scheme_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SchemeStore.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('eat：新建方案切换后为空白，默认「菜单」有内置数据', () async {
    await SchemeStore.migrateLegacy('eat');
    expect(await SchemeStore.current('eat'), '菜单');

    // 默认方案：内置数据
    await DataStore.load();
    expect(DataStore.dishes, isNotEmpty);

    // 新建「菜单二」并切换：应为空白
    await SchemeStore.create('eat', '菜单二');
    await SchemeStore.switchTo('eat', '菜单二');
    await DataStore.load();
    expect(DataStore.dishes, isEmpty, reason: '新方案不应填充内置菜单');
    expect(DataStore.staples, isEmpty);
    expect(DataStore.drinks, isEmpty);

    // 切回默认：内置数据恢复
    await SchemeStore.switchTo('eat', '菜单');
    await DataStore.load();
    expect(DataStore.dishes, isNotEmpty);
  });

  test('eat：自定义方案用户数据独立保存', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '我的菜单');
    await SchemeStore.switchTo('eat', '我的菜单');
    await DataStore.load();
    DataStore.dishes.add(FoodItem(name: '测试菜', ingredients: []));
    await DataStore.save();

    // 切到默认再切回：自定义数据还在
    await SchemeStore.switchTo('eat', '菜单');
    await DataStore.load();
    await SchemeStore.switchTo('eat', '我的菜单');
    await DataStore.load();
    expect(DataStore.dishes.any((d) => d.name == '测试菜'), isTrue);
  });

  test('go：新建方案切换后为空，默认「地点集」有内置数据', () async {
    await SchemeStore.migrateLegacy('go');
    expect(await SchemeStore.current('go'), '地点集');

    await GoDataStore.load();
    expect(GoDataStore.places, isNotEmpty);

    await SchemeStore.create('go', '新地点');
    await SchemeStore.switchTo('go', '新地点');
    await GoDataStore.load();
    expect(GoDataStore.places, isEmpty, reason: '新方案不应填充内置地点');
  });

  test('wear：新建方案切换后为空，默认「衣柜」有内置数据', () async {
    await SchemeStore.migrateLegacy('wear');
    expect(await SchemeStore.current('wear'), '衣柜');

    await WearDataStore.load();
    expect(WearDataStore.outfits, isNotEmpty);

    await SchemeStore.create('wear', '旅行装');
    await SchemeStore.switchTo('wear', '旅行装');
    await WearDataStore.load();
    expect(WearDataStore.outfits, isEmpty, reason: '新方案不应填充内置衣柜');
  });

  test('createWithData：AI 精选新建方案入库并切换（重名自动编号）', () async {
    await SchemeStore.migrateLegacy('eat');
    // 第一次：AI精选
    final name1 = await SchemeStore.createWithData('eat', 'AI精选', 'dishes', [
      {'name': '番茄炒蛋'},
    ]);
    expect(name1, 'AI精选');
    expect(await SchemeStore.current('eat'), 'AI精选');
    // 第二次：AI精选 2
    final name2 = await SchemeStore.createWithData('eat', 'AI精选', 'dishes', [
      {'name': '青椒肉丝'},
    ]);
    expect(name2, 'AI精选 2');
    expect(await SchemeStore.current('eat'), 'AI精选 2');
    // 数据可读回
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('eat_scheme_AI精选_dishes');
    expect(json, contains('番茄炒蛋'));
    expect(prefs.getString('eat_scheme_AI精选 2_dishes'), contains('青椒肉丝'));
    // 列表包含两个方案
    expect(await SchemeStore.list('eat'), containsAll(['AI精选', 'AI精选 2']));
  });
}
