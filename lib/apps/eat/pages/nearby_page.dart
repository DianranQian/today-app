import 'package:flutter/material.dart';
import 'package:location/location.dart';
import '../services/amap_api.dart';
import '../services/ai_service.dart';

class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
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
      throw Exception('需要定位权限才能搜索附近美食，请到系统设置中授权');
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
      final pois = await AmapApi.around(pos.latitude!, pos.longitude!);
      if (!mounted) return;
      setState(() {
        _pois = pois;
        _loading = false;
        _locationText = '当前位置：${pos.latitude!.toStringAsFixed(4)}, ${pos.longitude!.toStringAsFixed(4)}';
        if (pois.isEmpty) _error = '附近 3 公里内没有找到餐厅';
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
      final result = await AiService.analyzeNearby(_pois);
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
    return Scaffold(
      appBar: AppBar(title: const Text('附近美食')),
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
                    label: Text(_loading ? '正在搜索...' : '定位并搜索附近美食'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35),
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
                      label: Text(_aiLoading ? 'AI 思考中...' : 'AI 智能分析：附近值得吃哪家？'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6C4FBF),
                        side: const BorderSide(color: Color(0xFF6C4FBF)),
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
                    color: const Color(0xFFF5F1FF),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 16, color: Color(0xFF6C4FBF)),
                              SizedBox(width: 6),
                              Text('AI 推荐',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6C4FBF))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(_aiResult!, style: const TextStyle(fontSize: 13, height: 1.6)),
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
                        const Text('🍽️', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text('搜索后展示附近餐厅',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('支持按评分排序，并可用 AI 帮你分析',
                            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
                          leading: const Text('🍽️', style: TextStyle(fontSize: 24)),
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
                                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: rating > 0
                              ? Text(rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF6B35)))
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
