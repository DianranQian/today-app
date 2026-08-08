import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/data_store.dart';

class NearbyPoi {
  final String name;
  final String address;
  final String tel;
  final String type;
  final int distance;
  final String rating;
  final String cost;

  const NearbyPoi({
    required this.name,
    required this.address,
    required this.tel,
    required this.type,
    required this.distance,
    required this.rating,
    required this.cost,
  });

  factory NearbyPoi.fromJson(Map<String, dynamic> json) {
    final biz = json['biz_ext'] is Map
        ? (json['biz_ext'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return NearbyPoi(
      name: json['name'] as String? ?? '未知',
      address: json['address'] as String? ?? '',
      tel: json['tel'] as String? ?? '',
      type: json['type'] as String? ?? '',
      distance: int.tryParse(json['distance'] as String? ?? '0') ?? 0,
      rating: biz['rating'] as String? ?? '',
      cost: biz['cost'] as String? ?? '',
    );
  }
}

class AmapApi {
  static const _base = 'https://restapi.amap.com/v3/place/around';

  static String get _key => DataStore.settings.amapKey.trim();

  static bool get hasKey => _key.isNotEmpty;

  static Future<List<NearbyPoi>> around(double lat, double lng,
      {int radius = 3000}) async {
    if (!hasKey) {
      throw Exception('尚未配置高德地图 Key，请到「设置」中填写');
    }
    final uri = Uri.parse(_base).replace(queryParameters: {
      'key': _key,
      'location': '$lng,$lat',
      'types': '050000',
      'radius': '$radius',
      'offset': '25',
      'page': '1',
      'sortrule': 'weight',
      'extensions': 'base',
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('请求失败：HTTP ${resp.statusCode}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    if (json['status'] != '1') {
      throw Exception('高德接口错误：${json['info']}');
    }
    final list = (json['pois'] as List? ?? [])
        .map((p) => NearbyPoi.fromJson(p as Map<String, dynamic>))
        .toList();
    list.sort((a, b) {
      final ra = double.tryParse(a.rating) ?? 0;
      final rb = double.tryParse(b.rating) ?? 0;
      if (ra != rb) return rb.compareTo(ra);
      return a.distance.compareTo(b.distance);
    });
    return list;
  }
}
