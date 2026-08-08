import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/app_settings.dart';
import 'amap_api.dart';

class AiService {
  static const _endpoint = 'https://api.deepseek.com/chat/completions';

  static String get _apiKey => AppSettings.deepseekKey.trim();

  static bool get hasKey => _apiKey.isNotEmpty;

  static String buildPoiPrompt(List<NearbyPoi> pois) {
    final top = pois.take(15).toList();
    final lines = List.generate(top.length, (i) {
      final p = top[i];
      final rating = p.rating.isNotEmpty ? p.rating : '未知';
      final cost = p.cost.isNotEmpty ? '¥${p.cost}' : '未知';
      return '${i + 1}. ${p.name}（${p.type.isNotEmpty ? p.type : '餐饮'}）'
          ' 评分 $rating，人均 $cost，距离 ${p.distance}m'
          '${p.address.isNotEmpty ? '，地址：${p.address}' : ''}';
    }).join('\n');
    return lines;
  }

  static Future<String> analyzeNearby(List<NearbyPoi> pois) async {
    if (!hasKey) {
      throw Exception('尚未配置 DeepSeek Key，请到「设置」中填写');
    }
    if (pois.isEmpty) {
      throw Exception('附近暂无餐厅数据，请先搜索');
    }
    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'temperature': 1.2,
        'messages': [
          {
            'role': 'system',
            'content': '你是美食推荐助手。根据用户附近的餐厅 POI 数据，'
                '推荐 3 家最值得吃的，每家给出推荐理由和适合的场景。'
                '用中文回答，语言简洁，不要使用 Markdown 列表外的格式。',
          },
          {
            'role': 'user',
            'content': '附近餐厅数据如下：\n${buildPoiPrompt(pois)}',
          },
        ],
      }),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('AI 请求失败（HTTP ${resp.statusCode}）：'
          '${utf8.decode(resp.bodyBytes, allowMalformed: true)}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    return json['choices'][0]['message']['content'] as String;
  }
}
