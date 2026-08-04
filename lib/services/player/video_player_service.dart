// 播放器引擎抽象，统一 Android ExoPlayer 与桌面 media_kit 接口
// 对应原项目 MyVideoView + VideoViewManager 的对外能力
import 'dart:async';

abstract class VideoPlayerService {
  /// 初始化并加载 url
  Future<void> open(String url, {Map<String, String>? headers, bool autoPlay = true});

  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> setVolume(double volume);
  Future<void> dispose();

  /// 当前是否正在播放
  bool get isPlaying;
  /// 当前位置
  Duration get position;
  /// 总时长
  Duration get duration;
  /// 缓冲位置
  Duration get buffer;
  /// 播放速度
  double get speed;
  /// 音量 0..1
  double get volume;

  /// 状态变化流
  Stream<void> get onStateChanged;
  /// 位置变化流
  Stream<Duration> get onPositionChanged;
  /// 时长变化流
  Stream<Duration> get onDurationChanged;
  /// 错误流
  Stream<String> get onError;
  /// 播放完成流
  Stream<void> get onCompleted;
}

/// 状态变化事件
class PlayerStateEvent {
  PlayerStateEvent({this.playing, this.buffering, this.completed});
  final bool? playing;
  final bool? buffering;
  final bool? completed;
}
