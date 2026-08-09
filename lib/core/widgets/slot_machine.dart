import 'package:flutter/material.dart';

/// 老虎机公共组件：eat/go/wear 三子应用共用。
///
/// 结构：
/// - [RollingHint]：滚动中的提示胶囊（主题色）
/// - [SlotReel]：单列滚轮窗口（标题条 + 滚轮 + 渐隐 + 选中描边），
///   多列时用 Row 组合多个 SlotReel，单列时直接用。

/// 滚动提示胶囊
class RollingHint extends StatelessWidget {
  const RollingHint({super.key, this.text = '正在转动，稍等片刻...'});

  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final darkText = Color.lerp(primary, Colors.black, 0.35)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.casino, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 13, color: darkText)),
        ],
      ),
    );
  }
}

/// 单列滚轮窗口。
///
/// [emojiOf]/[nameOf] 将数据项映射为展示内容；[controller] 由调用方持有；
/// [enabled] 为 false 时显示灰色占位（未开启的列）。
class SlotReel<T> extends StatelessWidget {
  const SlotReel({
    super.key,
    required this.label,
    required this.items,
    required this.controller,
    required this.emojiOf,
    required this.nameOf,
    this.badgeOf,
    this.badgeColorOf,
    this.flex = 1,
    this.enabled = true,
    this.itemExtent = 56.0,
    this.wheelHeight = 176.0,
  });

  final String label;
  final List<T> items;
  final FixedExtentScrollController? controller;
  final String Function(T) emojiOf;
  final String Function(T) nameOf;

  /// 可选小角标（如性别标记）
  final String Function(T)? badgeOf;

  /// 角标颜色（可选，默认灰色）
  final Color? Function(T)? badgeColorOf;
  final int flex;
  final bool enabled;
  final double itemExtent;
  final double wheelHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final darkText = Color.lerp(primary, Colors.black, 0.35)!;
    final bg = theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow;

    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: primary.withAlpha(14),
          border: Border.all(color: primary.withAlpha(70)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // 列标题条
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              color: primary.withAlpha(45),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: darkText,
                      fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              height: wheelHeight,
              child: enabled
                  ? Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ListWheelScrollView.useDelegate(
                              controller: controller,
                              itemExtent: itemExtent,
                              physics: const FixedExtentScrollPhysics(),
                              useMagnifier: true,
                              magnification: 1.12,
                              overAndUnderCenterOpacity: 0.45,
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: items.length,
                                builder: (context, i) => Center(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(emojiOf(items[i]),
                                            style:
                                                const TextStyle(fontSize: 22)),
                                        const SizedBox(width: 6),
                                        if (badgeOf != null) ...[
                                          Text(badgeOf!(items[i]),
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: badgeColorOf
                                                          ?.call(items[i]) ??
                                                      Colors.grey[600])),
                                          const SizedBox(width: 4),
                                        ],
                                        Flexible(
                                          child: Text(nameOf(items[i]),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 上下渐隐
                        Positioned(
                          top: 0, left: 0, right: 0, height: 36,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [bg, bg.withAlpha(0)],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0, left: 0, right: 0, height: 36,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [bg, bg.withAlpha(0)],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 选中窗口圆角描边（白色半透明）
                        Positioned(
                          top: (wheelHeight - itemExtent) / 2,
                          left: 6,
                          right: 6,
                          height: itemExtent,
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.white.withAlpha(200),
                                    width: 1.5),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white.withAlpha(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.block, size: 20, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('未开启',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
