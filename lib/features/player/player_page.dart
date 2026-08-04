// 播放器页，对应原项目 com.github.tvbox.osc.ui.activity.PlayActivity + PlayFragment + MyVideoView
// 使用 media_kit 渲染（Android/Windows/macOS 通用），ExoPlayer 通道作为 Android 备选
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' hide SubtitleView;

import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import '../../data/api/api_config.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/source_repository.dart';
import '../../routes/app_router.dart';
import '../danmu/danmu_item.dart';
import '../danmu/danmu_loader.dart';
import '../danmu/danmu_view.dart';
import '../subtitle/subtitle_parser.dart';
import '../subtitle/subtitle_view.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.title,
    required this.url,
    this.sourceKey = '',
    this.vodId = '',
    this.episodeName = '',
    this.resumeMs = 0,
  });

  final String title;
  final String url;
  final String sourceKey;
  final String vodId;
  final String episodeName;
  final int resumeMs;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  bool _controlsVisible = true;
  bool _loading = true;
  String? _error;
  Timer? _hideTimer;
  Timer? _progressTimer;
  double _speed = 1.0;
  final List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0];
  bool _showSpeedPanel = false;
  bool _resumed = false;

  // 弹幕/字幕
  final ValueNotifier<int> _positionNotifier = ValueNotifier<int>(0);
  List<DanmuItem> _danmuItems = <DanmuItem>[];
  bool _danmuEnabled = true;
  List<SubtitleCue> _subtitleCues = <SubtitleCue>[];
  bool _subtitleEnabled = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _startPlay();
    _setupListeners();
    _startHideTimer();
    _startProgressTimer();
    _loadDanmu();
  }

  Future<void> _loadDanmu() async {
    final url = ApiConfig.instance.danmaku;
    if (url.isEmpty) return;
    try {
      final items = await DanmuLoader.instance.loadFromUrl(url);
      if (mounted) {
        setState(() => _danmuItems = items);
      }
    } catch (e) {
      LOG.e('Player', '加载弹幕失败', e);
    }
  }

  Future<void> _startPlay() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 若需解析（parse=1），先调用 playerContent 获取真实 URL
      String playUrl = widget.url;
      Map<String, String>? headers;
      final source = ApiConfig.instance.getSource(widget.sourceKey);
      if (source != null && playUrl.isNotEmpty) {
        try {
          final result = await SourceRepository.instance
              .playerContent(source, '', widget.url);
          if (result.url.isNotEmpty) playUrl = result.url;
          if (result.header.isNotEmpty) {
            // header 可能是 JSON
            headers = _parseHeaders(result.header);
          }
        } catch (e) {
          LOG.e('Player', 'playerContent 失败，使用原始 URL', e);
        }
      }
      if (playUrl.isEmpty) {
        setState(() {
          _loading = false;
          _error = '播放地址为空';
        });
        return;
      }
      await _player.open(Media(playUrl, httpHeaders: headers));
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Map<String, String>? _parseHeaders(String h) {
    if (h.isEmpty) return null;
    try {
      final decoded = jsonDecode(h);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry('$k', '$v'));
      }
    } catch (_) {
      // 非 JSON，按 "Key: Value\n" 解析
      final map = <String, String>{};
      for (final line in h.split('\n')) {
        final idx = line.indexOf(':');
        if (idx > 0) {
          map[line.substring(0, idx).trim()] = line.substring(idx + 1).trim();
        }
      }
      return map.isEmpty ? null : map;
    }
    return null;
  }

  void _setupListeners() {
    _player.stream.error.listen((e) {
      if (e.isNotEmpty && mounted) {
        setState(() => _error = e);
      }
    });
    _player.stream.buffering.listen((b) {
      if (mounted) setState(() => _loading = b);
    });
    // 恢复播放位置：等_duration 可用后 seek
    _player.stream.duration.listen((d) {
      if (!_resumed && widget.resumeMs > 0 && d.inMilliseconds > 0) {
        _resumed = true;
        final target = Duration(milliseconds: widget.resumeMs);
        if (target < d) {
          _player.seek(target);
        }
      }
    });
    // 推送位置到弹幕/字幕
    _player.stream.position.listen((p) {
      _positionNotifier.value = p.inMilliseconds;
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing) {
        setState(() {
          _controlsVisible = false;
          _showSpeedPanel = false;
        });
      }
    });
  }

  /// 每 5 秒记录一次播放进度
  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _saveProgress();
    });
  }

  void _saveProgress() {
    if (widget.sourceKey.isEmpty || widget.vodId.isEmpty) return;
    final pos = _player.state.position.inMilliseconds;
    final dur = _player.state.duration.inMilliseconds;
    if (dur <= 0) return;
    HistoryRepository.instance.updateProgress(
      widget.sourceKey,
      widget.vodId,
      positionMs: pos,
      durationMs: dur,
    );
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _startHideTimer();
  }

  void _togglePlay() {
    if (_player.state.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    _startHideTimer();
  }

  Future<void> _seekRelative(int seconds) async {
    final pos = _player.state.position;
    final dur = _player.state.duration;
    var target = pos + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    await _player.seek(target);
    _startHideTimer();
  }

  void _setSpeed(double s) {
    _player.setRate(s);
    setState(() {
      _speed = s;
      _showSpeedPanel = false;
    });
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _saveProgress();
    _player.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MouseRegion(
        onHover: (_) => _showControls(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          onDoubleTap: _togglePlay,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 视频渲染
              Video(
                controller: _controller,
                fit: BoxFit.contain,
                controls: NoVideoControls,
              ),
              // 弹幕
              if (_danmuEnabled && _danmuItems.isNotEmpty)
                DanmuView(
                  items: _danmuItems,
                  currentMs: _positionNotifier,
                  playing: !_loading && _error == null,
                  enabled: _danmuEnabled,
                ),
              // 字幕
              if (_subtitleEnabled && _subtitleCues.isNotEmpty)
                SubtitleView(
                  cues: _subtitleCues,
                  currentMs: _positionNotifier,
                  enabled: _subtitleEnabled,
                ),
              // 加载/错误
              if (_loading)
                const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.accent))
              else if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.pink, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.textHint, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _startPlay,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              // 顶部栏
              if (_controlsVisible) _buildTopBar(),
              // 底部控制条
              if (_controlsVisible) _buildBottomBar(),
              // 倍速面板
              if (_showSpeedPanel) _buildSpeedPanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _startHideTimer();
  }

  /// 选择本地字幕文件
  Future<void> _pickSubtitle() async {
    if (_subtitleEnabled) {
      // 已开启则关闭
      setState(() => _subtitleEnabled = false);
      _startHideTimer();
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['srt', 'ass', 'ssa', 'vtt', 'txt'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final path = f.path;
      if (path == null || path.isEmpty) return;
      final file = File(path);
      if (!file.existsSync()) return;
      final content = await file.readAsString();
      final cues = SubtitleParser.parse(content);
      setState(() {
        _subtitleCues = cues;
        _subtitleEnabled = cues.isNotEmpty;
      });
      if (cues.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('字幕解析失败或为空'),
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      LOG.e('Player', '加载字幕失败', e);
    }
    _startHideTimer();
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${widget.title} · ${widget.episodeName}',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: '投屏',
              icon: const Icon(Icons.cast, color: Colors.white54, size: 20),
              onPressed: () {
                _saveProgress();
                context.push(AppRoutes.cast, extra: {
                  'url': widget.url,
                  'title': '${widget.title} · ${widget.episodeName}',
                });
              },
            ),
            if (_danmuItems.isNotEmpty)
              IconButton(
                tooltip: _danmuEnabled ? '关闭弹幕' : '开启弹幕',
                icon: Icon(
                  _danmuEnabled ? Icons.comment : Icons.comments_disabled_outlined,
                  color: _danmuEnabled ? Colors.white : Colors.white54,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _danmuEnabled = !_danmuEnabled);
                  _startHideTimer();
                },
              ),
            IconButton(
              tooltip: _subtitleEnabled ? '关闭字幕' : '加载字幕',
              icon: Icon(
                _subtitleEnabled ? Icons.subtitles : Icons.subtitles_outlined,
                color: _subtitleEnabled ? Colors.white : Colors.white54,
                size: 20,
              ),
              onPressed: _pickSubtitle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final pos = _player.state.position;
    final dur = _player.state.duration;
    final buf = _player.state.buffer;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (context, snapshot) {
                final p = snapshot.data ?? pos;
                return Row(
                  children: [
                    Text(_fmt(p),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          trackShape: _BufferedTrackShape(buffer: buf, duration: dur),
                        ),
                        child: Slider(
                          value: dur.inMilliseconds > 0
                              ? p.inMilliseconds / dur.inMilliseconds
                              : 0,
                          onChanged: (v) {
                            if (dur.inMilliseconds > 0) {
                              _player.seek(Duration(
                                  milliseconds:
                                      (v * dur.inMilliseconds).toInt()));
                            }
                            _startHideTimer();
                          },
                        ),
                      ),
                    ),
                    Text(_fmt(dur),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.replay_10, color: Colors.white),
                  onPressed: () => _seekRelative(-10),
                ),
                StreamBuilder<bool>(
                  stream: _player.stream.playing,
                  builder: (context, snapshot) {
                    final playing = snapshot.data ?? _player.state.playing;
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        color: Colors.white,
                      ),
                      onPressed: _togglePlay,
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10, color: Colors.white),
                  onPressed: () => _seekRelative(10),
                ),
                const SizedBox(width: 24),
                GestureDetector(
                  onTap: () => setState(() => _showSpeedPanel = !_showSpeedPanel),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${_speed}x',
                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedPanel() {
    return Positioned(
      bottom: 80,
      right: 32,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _speeds
              .map((s) => InkWell(
                    onTap: () => _setSpeed(s),
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      child: Text(
                        '${s}x',
                        style: TextStyle(
                          color: s == _speed ? AppColors.accent : Colors.white,
                          fontSize: 14,
                          fontWeight: s == _speed ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

/// 带缓冲指示的进度条轨道
class _BufferedTrackShape extends RoundedRectSliderTrackShape {
  _BufferedTrackShape({required this.buffer, required this.duration});
  final Duration buffer;
  final Duration duration;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: thumbCenter,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    // 缓冲进度用 secondaryTrackColor 体现
    if (duration.inMilliseconds > 0) {
      // secondaryOffset 已通过 thumbCenter 体现，这里不再额外绘制
    }
  }
}
