import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:today_app/apps/wear/wear_data_store.dart';
import 'package:today_app/apps/wear/wear_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('男装过滤：排除 female 款，保留 male + unisex', () async {
    await WearDataStore.load();
    final pool = [
      OutfitItem(name: '碎花连衣裙', emoji: '🌸', scene: WearScene.daily,
          gender: WearGender.female),
      OutfitItem(name: 'T恤+牛仔裤', emoji: '👕', scene: WearScene.daily),
      OutfitItem(name: 'POLO衫+休闲裤', emoji: '👕', scene: WearScene.daily,
          gender: WearGender.male),
    ];
    final result = WearDataStore.getFilteredOutfits(
        gender: WearGender.male, pool: pool);
    final names = result.map((o) => o.name).toList();
    expect(names, containsAll(['T恤+牛仔裤', 'POLO衫+休闲裤']));
    expect(names, isNot(contains('碎花连衣裙')));
  });

  test('女装过滤：排除 male 款，保留 female + unisex', () async {
    await WearDataStore.load();
    final pool = [
      OutfitItem(name: '碎花连衣裙', emoji: '🌸', scene: WearScene.daily,
          gender: WearGender.female),
      OutfitItem(name: 'T恤+牛仔裤', emoji: '👕', scene: WearScene.daily),
      OutfitItem(name: 'POLO衫+休闲裤', emoji: '👕', scene: WearScene.daily,
          gender: WearGender.male),
    ];
    final result = WearDataStore.getFilteredOutfits(
        gender: WearGender.female, pool: pool);
    final names = result.map((o) => o.name).toList();
    expect(names, containsAll(['碎花连衣裙', 'T恤+牛仔裤']));
    expect(names, isNot(contains('POLO衫+休闲裤')));
  });

  test('内置默认库：男装过滤结果不含任何 female 款', () async {
    await WearDataStore.load();
    final result = WearDataStore.getFilteredOutfits(
        gender: WearGender.male,
        pool: List<OutfitItem>.of(WearDataStore.outfits));
    for (final o in result) {
      expect(o.gender == WearGender.female, isFalse,
          reason: '${o.name} 是女款却出现在男装结果里');
    }
    expect(result, isNotEmpty);
  });

  test('JSON 往返：gender 字段保留', () async {
    final item = OutfitItem(name: '连衣裙', gender: WearGender.female);
    final restored = OutfitItem.fromJson(item.toJson());
    expect(restored.gender, WearGender.female);
  });

  test('旧版数据修复：缺 gender 字段的连衣裙按内置库补齐为 female', () async {
    SharedPreferences.setMockInitialValues({
      'wear_schemes': ['衣柜'],
      'wear_scheme_current': '衣柜',
      'wear_scheme_random': ['衣柜'],
      'wear_scheme_衣柜_outfits':
          '[{"name":"连衣裙","emoji":"👗","scene":"daily","seasons":["summer"],"tempMin":22}]',
    });
    await WearDataStore.load();
    final dress = WearDataStore.outfits.firstWhere((o) => o.name == '连衣裙');
    expect(dress.gender, WearGender.female);
    // 修复后数据已写回 prefs
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('wear_scheme_衣柜_outfits');
    expect(saved, contains('"gender":"female"'));
  });
}
