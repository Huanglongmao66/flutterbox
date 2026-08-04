// 推送服务，对应原项目 PushActivity 的推送接收逻辑
// 监听 RemoteServer 事件，维护推送历史，并路由至播放器/搜索
import 'dart:async';

import '../../core/utils/log.dart';
import '../../services/remote_server.dart';

/// 推送记录
class PushRecord {
  PushRecord({
    required this.type,
    required this.data,
    required this.title,
    required this.time,
  });
  final String type; // play | search | url
  final String data;
  final String title;
  final DateTime time;

  Map<String, dynamic> toJson() => {
        'type': type,
        'data': data,
        'title': title,
        'time': time.toIso8601String(),
      };
}

/// 推送服务（单例）
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final List<PushRecord> _history = <PushRecord>[];
  StreamSubscription<RemoteEvent>? _sub;

  /// 推送事件流（供 UI 响应）
  final StreamController<PushRecord> _eventController =
      StreamController<PushRecord>.broadcast();
  Stream<PushRecord> get events => _eventController.stream;

  List<PushRecord> get history => List.unmodifiable(_history);

  /// 启动监听（在 bootstrap 中调用）
  void start() {
    _sub?.cancel();
    _sub = RemoteServer.instance.events.listen(_onEvent);
    LOG.i('PushService', '推送服务已启动');
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void _onEvent(RemoteEvent event) {
    final title = (event.extra?['title'] ?? '') as String;
    final record = PushRecord(
      type: event.type,
      data: event.data,
      title: title,
      time: DateTime.now(),
    );
    _history.insert(0, record);
    if (_history.length > 100) _history.removeLast();
    _eventController.add(record);
  }

  void clear() {
    _history.clear();
  }
}
