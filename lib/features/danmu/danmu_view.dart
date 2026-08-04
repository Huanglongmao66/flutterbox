// 弹幕渲染组件，对应原项目 DanmuHelper + CustomDanmuView
// 滚动/顶部/底部三种模式，支持透明度/字号/速度/最大行数
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/constants/hawk_config.dart';
import '../../core/storage/hawk_store.dart';
import 'danmu_item.dart';

class DanmuView extends StatefulWidget {
  const DanmuView({
    super.key,
    required this.items,
    required this.currentMs,
    required this.playing,
    this.enabled = true,
  });

  final List<DanmuItem> items;
  final ValueNotifier<int> currentMs;
  final bool playing;
  final bool enabled;

  @override
  State<DanmuView> createState() => _DanmuViewState();
}

class _DanmuViewState extends State<DanmuView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_ActiveDanmu> _active = <_ActiveDanmu>[];
  int _lastEmittedIndex = 0;
  int _lastMs = 0;

  // 配置
  double _alpha = 1.0;
  double _sizeScale = 1.0;
  int _maxLine = 5;
  double _speed = 1.0;
  bool _show = true;

  // 行轨道占用：滚动/顶部/底部
  final List<double> _scrollLaneEnd = <double>[];
  final List<double> _topLaneEnd = <double>[];
  final List<double> _bottomLaneEnd = <double>[];
  static const double _laneHeight = 36.0;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _lastMs = widget.currentMs.value;
    _ticker = _createTicker();
    if (widget.enabled && _show) _ticker.start();
    widget.currentMs.addListener(_onPositionChanged);
  }

  void _loadConfig() {
    _alpha = (HawkStore.get<double>(HawkConfig.danmuAlpha, defaultValue: 1.0) ??
            1.0)
        .toDouble();
    _sizeScale = (HawkStore.get<double>(HawkConfig.danmuSizeScale, defaultValue: 1.0) ??
            1.0)
        .toDouble();
    _maxLine = HawkStore.get<int>(HawkConfig.danmuMaxLine, defaultValue: 5) ?? 5;
    _speed =
        (HawkStore.get<double>(HawkConfig.danmuSpeed, defaultValue: 1.0) ?? 1.0)
            .toDouble();
    _show = HawkStore.get<bool>(HawkConfig.danmuOpen, defaultValue: true) ?? true;
    _scrollLaneEnd.clear();
    _topLaneEnd.clear();
    _bottomLaneEnd.clear();
    for (int i = 0; i < _maxLine; i++) {
      _scrollLaneEnd.add(0);
      _topLaneEnd.add(0);
      _bottomLaneEnd.add(0);
    }
  }

  Ticker _createTicker() {
    return Ticker(_onTick);
  }

  void _onTick(Duration elapsed) {
    if (!mounted || !widget.playing) return;
    final now = widget.currentMs.value;
    // 发射时间窗口内的弹幕
    _emitItems(now);
    // 清理过期弹幕
    final changed = _cleanup(now);
    if (changed || _active.any((a) => a.item.mode == DanmuMode.scroll)) {
      setState(() {});
    }
  }

  void _onPositionChanged() {
    final now = widget.currentMs.value;
    // 跳跃（seek）处理：重置索引
    if ((now - _lastMs).abs() > 2000) {
      _active.clear();
      _lastEmittedIndex = _findStartIndex(now);
    }
    _lastMs = now;
  }

  int _findStartIndex(int ms) {
    if (widget.items.isEmpty) return 0;
    int lo = 0, hi = widget.items.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (widget.items[mid].time < ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _emitItems(int now) {
    if (widget.items.isEmpty) return;
    final w = context.size?.width ?? 0;
    if (w == 0) return;
    while (_lastEmittedIndex < widget.items.length) {
      final item = widget.items[_lastEmittedIndex];
      if (item.time > now) break;
      if (now - item.time <= 2000) {
        _addToActive(item, now, w);
      }
      _lastEmittedIndex++;
    }
    // 回环：播放进度倒退后，索引可能滞后
    if (_lastEmittedIndex >= widget.items.length && widget.items.isNotEmpty) {
      // 不重置，等待 seek 触发
    }
  }

  void _addToActive(DanmuItem item, int now, double width) {
    final lane = _pickLane(item.mode, now, width);
    if (lane < 0) return; // 轨道占满，丢弃
    final tp = TextPainter(
      text: TextSpan(
        text: item.text,
        style: TextStyle(
          color: item.colorValue,
          fontSize: (item.size > 0 ? item.size : 22) * _sizeScale,
          fontWeight: FontWeight.w500,
          shadows: const [
            Shadow(offset: Offset(1, 1), blurRadius: 1, color: Colors.black54),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textWidth = tp.width;
    final durationMs = (8000 / _speed).round();
    _active.add(_ActiveDanmu(
      item: item,
      lane: lane,
      textPainter: tp,
      textWidth: textWidth,
      startMs: now,
      durationMs: durationMs,
      width: width,
    ));
    switch (item.mode) {
      case DanmuMode.scroll:
        _scrollLaneEnd[lane] = (now + (textWidth / _speed).round()).toDouble();
        break;
      case DanmuMode.top:
        _topLaneEnd[lane] = now + 4000;
        break;
      case DanmuMode.bottom:
        _bottomLaneEnd[lane] = now + 4000;
        break;
    }
  }

  int _pickLane(DanmuMode mode, int now, double width) {
    final lanes = mode == DanmuMode.scroll
        ? _scrollLaneEnd
        : (mode == DanmuMode.top ? _topLaneEnd : _bottomLaneEnd);
    for (int i = 0; i < lanes.length; i++) {
      if (lanes[i] <= now) return i;
    }
    return -1;
  }

  bool _cleanup(int now) {
    final before = _active.length;
    _active.removeWhere((a) {
      if (a.item.mode == DanmuMode.scroll) {
        return now - a.startMs >= a.durationMs;
      }
      return now - a.startMs >= 4000;
    });
    return _active.length != before;
  }

  @override
  void didUpdateWidget(covariant DanmuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled && _show) {
        _ticker.start();
      } else {
        _ticker.stop();
        _active.clear();
      }
    }
    if (oldWidget.items != widget.items) {
      _active.clear();
      _lastEmittedIndex = _findStartIndex(widget.currentMs.value);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.currentMs.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_show || _active.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Opacity(
        opacity: _alpha,
        child: CustomPaint(
          painter: _DanmuPainter(_active, widget.currentMs.value, _laneHeight),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ActiveDanmu {
  _ActiveDanmu({
    required this.item,
    required this.lane,
    required this.textPainter,
    required this.textWidth,
    required this.startMs,
    required this.durationMs,
    required this.width,
  });

  final DanmuItem item;
  final int lane;
  final TextPainter textPainter;
  final double textWidth;
  final int startMs;
  final int durationMs;
  final double width;
}

class _DanmuPainter extends CustomPainter {
  _DanmuPainter(this.active, this.now, this.laneHeight);

  final List<_ActiveDanmu> active;
  final int now;
  final double laneHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final a in active) {
      final top = a.lane * laneHeight + 8;
      double left;
      if (a.item.mode == DanmuMode.scroll) {
        final progress = (now - a.startMs) / a.durationMs;
        // 从右向左：x = width + textWidth - progress*(width+textWidth)
        left = a.width - progress * (a.width + a.textWidth);
      } else if (a.item.mode == DanmuMode.top) {
        left = (size.width - a.textWidth) / 2;
      } else {
        // bottom
        left = (size.width - a.textWidth) / 2;
      }
      final offset = Offset(left, top);
      a.textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant _DanmuPainter oldDelegate) => true;
}
