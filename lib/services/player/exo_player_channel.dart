// Android ExoPlayer 平台通道（Dart 端）
// 通过 MethodChannel + 平台视图与原生 ExoPlayer 通信
// 原生端见 android/app/src/main/kotlin/.../ExoPlayerPlugin.kt
import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import 'video_player_service.dart';

class ExoPlayerChannelService implements VideoPlayerService {
  ExoPlayerChannelService() : _channel = const MethodChannel('tvbox/player/exo');

  final MethodChannel _channel;

  // 状态缓存
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double _speed = 1.0;
  double _volume = 1.0;

  final StreamController<void> _stateCtrl = StreamController<void>.broadcast();
  final StreamController<Duration> _posCtrl = StreamController<Duration>.broadcast();
  final StreamController<Duration> _durCtrl = StreamController<Duration>.broadcast();
  final StreamController<String> _errCtrl = StreamController<String>.broadcast();
  final StreamController<void> _completeCtrl = StreamController<void>.broadcast();

  bool _inited = false;

  void _ensureChannel() {
    if (_inited) return;
    _inited = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPlaying':
          _isPlaying = true;
          _stateCtrl.add(null);
          break;
        case 'onPaused':
          _isPlaying = false;
          _stateCtrl.add(null);
          break;
        case 'onPosition':
          _position = Duration(milliseconds: (call.arguments as num?)?.toInt() ?? 0);
          _posCtrl.add(_position);
          break;
        case 'onDuration':
          _duration = Duration(milliseconds: (call.arguments as num?)?.toInt() ?? 0);
          _durCtrl.add(_duration);
          break;
        case 'onBuffering':
          // arguments = buffered ms
          _buffer = Duration(milliseconds: (call.arguments as num?)?.toInt() ?? 0);
          break;
        case 'onCompleted':
          _isPlaying = false;
          _completeCtrl.add(null);
          _stateCtrl.add(null);
          break;
        case 'onError':
          _errCtrl.add((call.arguments as String?) ?? '播放错误');
          break;
      }
    });
  }

  @override
  Future<void> open(String url, {Map<String, String>? headers, bool autoPlay = true}) async {
    _ensureChannel();
    await _channel.invokeMethod('open', {
      'url': url,
      'headers': headers ?? <String, String>{},
      'autoPlay': autoPlay,
    });
  }

  @override
  Future<void> play() => _channel.invokeMethod('play');

  @override
  Future<void> pause() => _channel.invokeMethod('pause');

  @override
  Future<void> seekTo(Duration position) =>
      _channel.invokeMethod('seek', position.inMilliseconds);

  @override
  Future<void> setSpeed(double speed) {
    _speed = speed;
    return _channel.invokeMethod('setSpeed', speed);
  }

  @override
  Future<void> setVolume(double volume) {
    _volume = volume;
    return _channel.invokeMethod('setVolume', volume);
  }

  @override
  Future<void> dispose() async {
    try {
      await _channel.invokeMethod('dispose');
    } catch (_) {}
    await _stateCtrl.close();
    await _posCtrl.close();
    await _durCtrl.close();
    await _errCtrl.close();
    await _completeCtrl.close();
  }

  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get position => _position;
  @override
  Duration get duration => _duration;
  @override
  Duration get buffer => _buffer;
  @override
  double get speed => _speed;
  @override
  double get volume => _volume;

  @override
  Stream<void> get onStateChanged => _stateCtrl.stream;
  @override
  Stream<Duration> get onPositionChanged => _posCtrl.stream;
  @override
  Stream<Duration> get onDurationChanged => _durCtrl.stream;
  @override
  Stream<String> get onError => _errCtrl.stream;
  @override
  Stream<void> get onCompleted => _completeCtrl.stream;
}

/// 工厂：按平台选择引擎
VideoPlayerService createPlayerService({PlayerEngine engine = PlayerEngine.auto}) {
  final use = engine == PlayerEngine.auto
      ? (isAndroid ? PlayerEngine.exo : PlayerEngine.mediaKit)
      : engine;
  switch (use) {
    case PlayerEngine.exo:
      return ExoPlayerChannelService();
    case PlayerEngine.mediaKit:
      // 由调用方提供 Player 实例，这里返回包装需在 player_page 注入
      // 见 player_page 中的 MediaKit 初始化
      throw StateError('media_kit 引擎需通过 createMediaKitService 创建');
    case PlayerEngine.auto:
      throw StateError('unreachable');
  }
}

enum PlayerEngine { auto, exo, mediaKit }
