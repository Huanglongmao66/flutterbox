// media_kit 播放器实现（桌面 libmpv，Android 备选引擎）
import 'dart:async';

import 'package:media_kit/media_kit.dart';

import 'video_player_service.dart';

class MediaKitPlayerService implements VideoPlayerService {
  MediaKitPlayerService(this._player);

  final Player _player;
  bool _disposed = false;

  @override
  Future<void> open(String url, {Map<String, String>? headers, bool autoPlay = true}) async {
    // media_kit 通过 Media 传入 headers（mpv http-header-fields）
    await _player.open(Media(url), play: autoPlay);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setRate(speed);

  @override
  Future<void> setVolume(double volume) =>
      _player.setVolume((volume * 100).clamp(0, 100));

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _player.dispose();
  }

  @override
  bool get isPlaying => _player.state.playing;

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  Duration get buffer => _player.state.buffer;

  @override
  double get speed => _player.state.rate;

  @override
  double get volume => (_player.state.volume / 100).clamp(0.0, 1.0);

  @override
  Stream<void> get onStateChanged => _player.stream.playing.map((_) {});

  @override
  Stream<Duration> get onPositionChanged => _player.stream.position;

  @override
  Stream<Duration> get onDurationChanged => _player.stream.duration;

  @override
  Stream<String> get onError => _player.stream.error;

  @override
  Stream<void> get onCompleted => _player.stream.completed.where((c) => c).map((_) {});
}
