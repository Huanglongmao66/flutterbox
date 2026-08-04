// 弹幕数据模型，对应原项目 DanmuHelper 中的弹幕项
// 支持滚动/顶部/底部三种模式
import 'dart:ui';

class DanmuItem {
  DanmuItem({
    required this.time,
    required this.text,
    required this.color,
    required this.mode,
    this.size = 0,
  });

  /// 出现时间（毫秒）
  final int time;
  final String text;
  final int color;
  final DanmuMode mode;
  final int size;

  Color get colorValue => Color(color | 0xFF000000);
}

enum DanmuMode {
  scroll, // 从右到左滚动
  top, // 顶部固定
  bottom, // 底部固定
}

class DanmuTrack {
  DanmuTrack({required this.items});

  final List<DanmuItem> items;
}
