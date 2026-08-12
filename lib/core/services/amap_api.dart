import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_settings.dart';
import '../language.dart';

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
    // 安全取值：高德返回字段可能为非字符串（空数组等），用字符串插值兜底
    String safeStr(dynamic v) => v is String ? v : '${v ?? ''}';
    return NearbyPoi(
      name: safeStr(json['name']).isEmpty ? '未知' : safeStr(json['name']),
      address: safeStr(json['address']),
      tel: safeStr(json['tel']),
      type: safeStr(json['type']),
      distance: int.tryParse('${json['distance'] ?? '0'}') ?? 0,
      rating: safeStr(biz['rating']),
      cost: safeStr(biz['cost']),
    );
  }
}

class AmapApi {
  static const _base = 'https://restapi.amap.com/v3/place/around';

  static String get _key => AppSettings.amapKey.trim();

  static bool get hasKey => _key.isNotEmpty;

  static Future<List<NearbyPoi>> around(double lat, double lng,
      {int radius = 3000, String types = '050000'}) async {
    if (!hasKey) {
      throw Exception(
          t('尚未配置高德地图 Key，请到「设置」中填写'));
    }
    final params = <String, String>{
      'key': _key,
      'location': '$lng,$lat',
      'radius': '$radius',
      'offset': '25',
      'page': '1',
      'sortrule': 'weight',
      'extensions': 'base',
    };
    if (types.isNotEmpty) params['types'] = types;
    // 手拼查询串，避免 Uri.replace 把 | 编码成 %7C
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final uri = Uri.parse('$_base?$qs');
    final resp = await http.get(uri).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception(t('请求失败：HTTP ${resp.statusCode}',
          'Request failed: HTTP ${resp.statusCode}'));
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    if (json['status'] != '1') {
      throw Exception(
          t('高德接口错误：${json['info']}', 'AMap API error: ${json['info']}'));
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
