import 'dart:convert';
import 'package:http/http.dart' as http;
import '../app_settings.dart';
import '../language.dart';
import 'amap_api.dart';

class AiService {
  static const _endpoint = 'https://api.deepseek.com/chat/completions';

  static String get _apiKey => AppSettings.deepseekKey.trim();

  static bool get hasKey => _apiKey.isNotEmpty;

  /// 通用对话（配置 AI 汇总等场景）
  static Future<String> chat(String systemPrompt, String userContent) async {
    if (!hasKey) {
      throw Exception(
          t('尚未配置 DeepSeek Key，请到「通用设置」中填写'));
    }
    final resp = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek-chat',
        'temperature': 0.8,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userContent},
        ],
      }),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception(t('AI 请求失败（HTTP ${resp.statusCode}）：',
          'AI request failed (HTTP ${resp.statusCode}): ') +
          '${utf8.decode(resp.bodyBytes, allowMalformed: true)}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes));
    return json['choices'][0]['message']['content'] as String;
  }

  static String buildPoiPrompt(List<NearbyPoi> pois, {String label = '餐饮'}) {
    final top = pois.take(15).toList();
    final lines = List.generate(top.length, (i) {
      final p = top[i];
      final rating = p.rating.isNotEmpty ? p.rating : '未知';
      final cost = p.cost.isNotEmpty ? '¥${p.cost}' : '未知';
      return '${i + 1}. ${p.name}（${p.type.isNotEmpty ? p.type : label}）'
          ' 评分 $rating，人均 $cost，距离 ${p.distance}m'
          '${p.address.isNotEmpty ? '，地址：${p.address}' : ''}';
    }).join('\n');
    return lines;
  }

  /// 分析附近 POI。
  /// [systemPrompt] 控制 AI 角色（吃什么：推荐餐厅；去哪：推荐去处）。
  /// [poiLabel] 展示用类型名。
  static Future<String> analyzeNearby(
    List<NearbyPoi> pois, {
    String systemPrompt =
        '你是美食推荐助手。根据用户附近的餐厅 POI 数据，推荐 3 家最值得吃的，'
            '每家给出推荐理由和适合的场景。用中文回答，语言简洁。',
    String poiLabel = '餐饮',
  }) async {
    if (!hasKey) {
      throw Exception(
          t('尚未配置 DeepSeek Key，请到「设置」中填写'));
    }
    if (pois.isEmpty) {
      throw Exception(t('附近暂无数据，请先搜索'));
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
          {'role': 'system', 'content': systemPrompt},
          {
            'role': 'user',
            'content': '附近 POI 数据如下：\n${buildPoiPrompt(pois, label: poiLabel)}',
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
