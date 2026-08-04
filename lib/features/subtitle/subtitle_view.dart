// 字幕渲染组件，对应原项目 SubtitleView
// 根据当前播放进度显示对应字幕，支持字号/延迟/开关
import 'package:flutter/material.dart';

import '../../core/constants/hawk_config.dart';
import '../../core/storage/hawk_store.dart';
import 'subtitle_parser.dart';

class SubtitleView extends StatefulWidget {
  const SubtitleView({
    super.key,
    required this.cues,
    required this.currentMs,
    this.enabled = true,
  });

  final List<SubtitleCue> cues;
  final ValueNotifier<int> currentMs;
  final bool enabled;

  @override
  State<SubtitleView> createState() => _SubtitleViewState();
}

class _SubtitleViewState extends State<SubtitleView> {
  double _textSize = 24.0;
  int _delayMs = 0;
  bool _show = true;
  SubtitleCue? _current;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    widget.currentMs.addListener(_onPositionChanged);
  }

  void _loadConfig() {
    _textSize =
        (HawkStore.get<double>(HawkConfig.subtitleTextSize, defaultValue: 24.0) ??
                24.0)
            .toDouble();
    _delayMs =
        HawkStore.get<int>(HawkConfig.subtitleTimeDelay, defaultValue: 0) ?? 0;
    _show = true;
  }

  void _onPositionChanged() {
    if (!widget.enabled || !_show || widget.cues.isEmpty) {
      if (_current != null) {
        setState(() => _current = null);
      }
      return;
    }
    final ms = widget.currentMs.value + _delayMs;
    final cue = _findCue(ms);
    if (cue != _current) {
      setState(() => _current = cue);
    }
  }

  SubtitleCue? _findCue(int ms) {
    if (widget.cues.isEmpty) return null;
    // 二分查找
    int lo = 0, hi = widget.cues.length - 1;
    SubtitleCue? found;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final c = widget.cues[mid];
      if (c.contains(ms)) {
        found = c;
        break;
      }
      if (ms < c.start) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
    return found;
  }

  @override
  void didUpdateWidget(covariant SubtitleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cues != widget.cues) {
      _current = null;
      _onPositionChanged();
    }
  }

  @override
  void dispose() {
    widget.currentMs.removeListener(_onPositionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !_show || _current == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: const EdgeInsets.only(bottom: 80),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _current!.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: _textSize,
              height: 1.3,
              shadows: const [
                Shadow(offset: Offset(1, 1), blurRadius: 2, color: Colors.black),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
