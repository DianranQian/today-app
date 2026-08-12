import 'package:flutter/material.dart';
import 'package:location/location.dart';
import '../../core/services/amap_api.dart';
import '../../core/services/ai_service.dart';

/// 「今天去哪」附近：定位 + 周边去处 + AI 分析（提示词针对去处）
class GoNearbyPage extends StatefulWidget {
  const GoNearbyPage({super.key});

  @override
  State<GoNearbyPage> createState() => _GoNearbyPageState();
}

class _GoNearbyPageState extends State<GoNearbyPage> {
  List<NearbyPoi> _pois = [];
  bool _loading = false;
  String? _error;
  String? _locationText;
  String? _aiResult;
  bool _aiLoading = false;

  Future<LocationData> _getPosition() async {
    final location = Location();
    if (!await location.serviceEnabled()) {
      final ok = await location.requestService();
      if (!ok) throw Exception('需要开启系统定位服务');
    }
    var permission = await location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await location.requestPermission();
    }
    if (permission == PermissionStatus.denied ||
        permission == PermissionStatus.deniedForever) {
      throw Exception('需要定位权限才能搜索附近去处，请到系统设置中授权');
    }
    final pos = await location.getLocation();
    if (pos.latitude == null || pos.longitude == null) {
      throw Exception('定位失败，请稍后重试');
    }
    return pos;
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _aiResult = null;
    });
    try {
      final pos = await _getPosition();
      final pois = await AmapApi.around(pos.latitude!, pos.longitude!, types: '');
      if (!mounted) return;
      setState(() {
        _pois = pois;
        _loading = false;
        _locationText =
            '当前位置：${pos.latitude!.toStringAsFixed(4)}, ${pos.longitude!.toStringAsFixed(4)}';
        if (pois.isEmpty) _error = '附近 3 公里内没有找到去处';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _analyze() async {
    setState(() => _aiLoading = true);
    try {
      final result = await AiService.analyzeNearby(
        _pois,
        systemPrompt: '你是出行推荐助手。根据用户附近的 POI 数据（餐饮/商场/公园等），'
            '推荐 3 个最值得去的去处，说明类型、推荐理由和适合的场景（约会/遛娃/朋友聚会等）。'
            '用中文回答，语言简洁。',
        poiLabel: '去处',
      );
      if (!mounted) return;
      setState(() {
        _aiResult = result;
        _aiLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('附近去处'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: Text(_loading ? '正在搜索...' : '定位并搜索附近去处'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
                if (_locationText != null) ...[
                  const SizedBox(height: 8),
                  Text(_locationText!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (_pois.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _aiLoading ? null : _analyze,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(_aiLoading ? 'AI 思考中...' : 'AI 推荐：附近值得去哪？'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: BorderSide(color: primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                ],
                if (_aiResult != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: primary.withAlpha(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome,
                                  size: 16, color: primary),
                              const SizedBox(width: 6),
                              const Text('AI 推荐',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(_aiResult!,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.6)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!,
                      style: const TextStyle(fontSize: 13, color: Colors.red)),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _pois.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text('搜索后展示附近去处',
                            style:
                                TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('支持 AI 分析帮你决定去哪',
                            style:
                                TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _pois.length,
                    itemBuilder: (context, index) {
                      final p = _pois[index];
                      final rating = double.tryParse(p.rating) ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const Text('📍', style: TextStyle(fontSize: 24)),
                          title: Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                [
                                  if (rating > 0) '评分 $rating',
                                  if (p.cost.isNotEmpty) '人均 ¥${p.cost}',
                                  '${p.distance}m',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (p.address.isNotEmpty)
                                Text(p.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: rating > 0
                              ? Text(rating.toStringAsFixed(1),
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primary))
                              : null,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
