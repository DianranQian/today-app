import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:today_app/core/scheme_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SchemeStore.resetForTest();
    SharedPreferences.setMockInitialValues({});
  });

  test('迁移：旧键复制到默认方案，旧键保留', () async {
    SharedPreferences.setMockInitialValues({
      'dishes': '[{"name":"A"}]',
      'go_places': '[{"name":"P"}]',
    });
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.migrateLegacy('go');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('eat_scheme_菜单_dishes'), '[{"name":"A"}]');
    expect(prefs.getString('dishes'), '[{"name":"A"}]');
    expect(prefs.getString('go_scheme_地点集_places'), '[{"name":"P"}]');
    expect(await SchemeStore.current('eat'), '菜单');
    expect(await SchemeStore.current('go'), '地点集');
    expect(await SchemeStore.randomPool('go'), ['地点集']);
  });

  test('默认方案名按应用区分', () async {
    expect(SchemeStore.defaultSchemeName('eat'), '菜单');
    expect(SchemeStore.defaultSchemeName('go'), '地点集');
    expect(SchemeStore.defaultSchemeName('wear'), '衣柜');
    expect(SchemeStore.defaultSchemeName('contact'), '电话簿');
  });

  test('迁移幂等：二次调用不重复写入', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.migrateLegacy('eat');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('eat_schemes'), ['菜单']);
  });

  test('创建 / 重命名 / 删除', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '菜单二');
    expect(await SchemeStore.list('eat'), ['菜单', '菜单二']);
    await SchemeStore.rename('eat', '菜单二', '周末');
    expect(await SchemeStore.list('eat'), ['菜单', '周末']);
    await SchemeStore.remove('eat', '周末');
    expect(await SchemeStore.list('eat'), ['菜单']);
  });

  test('重名拒绝', () async {
    await SchemeStore.migrateLegacy('eat');
    expect(() => SchemeStore.create('eat', '菜单'), throwsArgumentError);
  });

  test('当前方案禁止删除', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '菜单二');
    await SchemeStore.switchTo('eat', '菜单二');
    expect(await SchemeStore.current('eat'), '菜单二');
    expect(() => SchemeStore.remove('eat', '菜单二'), throwsArgumentError);
  });

  test('重命名迁移数据键 + 更新 current/random', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '菜单二');
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('eat_scheme_菜单二_dishes', '[{"name":"X"}]');
    await SchemeStore.switchTo('eat', '菜单二');
    await SchemeStore.setRandomPool('eat', ['菜单', '菜单二']);
    await SchemeStore.rename('eat', '菜单二', '周末');
    expect(prefs.getString('eat_scheme_周末_dishes'), '[{"name":"X"}]');
    expect(prefs.getString('eat_scheme_菜单二_dishes'), isNull);
    expect(await SchemeStore.current('eat'), '周末');
    expect(await SchemeStore.randomPool('eat'), ['菜单', '周末']);
  });

  test('随机池默认仅当前方案；可多选', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '菜单二');
    expect(await SchemeStore.randomPool('eat'), ['菜单']);
    await SchemeStore.setRandomPool('eat', ['菜单', '菜单二']);
    expect(await SchemeStore.randomPool('eat'), ['菜单', '菜单二']);
  });

  test('notify 每次操作都触发通知（即使同 appId 值不变）', () async {
    await SchemeStore.migrateLegacy('eat');
    var count = 0;
    SchemeStore.notifier.addListener(() => count++);
    await SchemeStore.create('eat', '菜单二'); // notify
    await SchemeStore.create('eat', '菜单三'); // 值不变也要通知
    await SchemeStore.setRandomPool('eat', ['菜单']);
    expect(count, greaterThanOrEqualTo(3));
  });

  test('rawPoolItems：仅当前方案返回 null', () async {
    await SchemeStore.migrateLegacy('eat');
    expect(await SchemeStore.rawPoolItems('eat', 'dishes'), isNull);
  });

  test('rawPoolItems：多方案按 name 去重合并', () async {
    await SchemeStore.migrateLegacy('eat');
    await SchemeStore.create('eat', '菜单二');
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('eat_scheme_菜单_dishes',
        '[{"name":"A"},{"name":"B"}]');
    prefs.setString('eat_scheme_菜单二_dishes',
        '[{"name":"B"},{"name":"C"}]');
    await SchemeStore.setRandomPool('eat', ['菜单', '菜单二']);
    final raw = await SchemeStore.rawPoolItems('eat', 'dishes');
    expect(raw!.map((m) => m['name']).toList(), ['A', 'B', 'C']);
  });
}
