// 远程控制服务，对应原项目 com.github.tvbox.osc.server.RemoteServer / ControlManager
// 内置 HTTP 服务（默认端口 9978），接收远程指令：推送播放、搜索、获取配置等
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/constants/app_constants.dart';
import '../core/storage/hawk_store.dart';
import '../core/constants/hawk_config.dart';
import '../core/utils/log.dart';

/// 远程指令事件
class RemoteEvent {
  RemoteEvent({required this.type, required this.data, this.extra});
  final String type; // 'play' | 'search' | 'url'
  final String data; // 主数据（URL/搜索词）
  final Map<String, dynamic>? extra;
}

/// 远程控制服务（单例）
class RemoteServer {
  RemoteServer._();
  static final RemoteServer instance = RemoteServer._();

  HttpServer? _server;
  bool _running = false;
  int _port = AppConstants.remoteServerPort;

  /// 事件流，UI 订阅以响应远程指令
  final StreamController<RemoteEvent> _eventController =
      StreamController<RemoteEvent>.broadcast();
  Stream<RemoteEvent> get events => _eventController.stream;

  bool get isRunning => _running;
  int get port => _port;

  /// 启动服务
  Future<void> start({int? port}) async {
    if (_running) return;
    _port = port ?? AppConstants.remoteServerPort;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      _running = true;
      LOG.i('RemoteServer', '远程控制服务已启动: 0.0.0.0:$_port');
      _server!.listen(_handleRequest);
    } catch (e) {
      LOG.e('RemoteServer', '启动失败 (port=$_port)', e);
      // 端口占用时尝试递增
      if (_port < AppConstants.remoteServerPort + 10) {
        await start(port: _port + 1);
      }
    }
  }

  /// 停止服务
  Future<void> stop() async {
    if (!_running) return;
    await _server?.close(force: true);
    _server = null;
    _running = false;
    LOG.i('RemoteServer', '远程控制服务已停止');
  }

  void _handleRequest(HttpRequest request) {
    try {
      final path = request.uri.path;
      if (path == '/do') {
        _handleDo(request);
      } else if (path == '/files' || path.startsWith('/files/')) {
        _handleFiles(request);
      } else if (path == '/status') {
        _handleStatus(request);
      } else if (path == '/' || path.isEmpty) {
        _ok(request, 'TVBox Flutter Remote Server');
      } else {
        _ok(request, jsonEncode({'code': 404, 'msg': 'not found'}));
      }
    } catch (e) {
      LOG.e('RemoteServer', '处理请求失败', e);
      _ok(request, jsonEncode({'code': 500, 'msg': '$e'}));
    }
  }

  /// /do?txt=<base64> —— 原项目核心指令入口
  /// txt 解码后为 JSON: {"action": "push", "url": "...", "title": "..."}
  Future<void> _handleDo(HttpRequest request) async {
    final txt = request.uri.queryParameters['txt'] ?? '';
    String payload;
    try {
      payload = utf8.decode(base64.decode(txt));
    } catch (_) {
      // 非编码则当原文
      payload = txt;
    }
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(payload) as Map).cast<String, dynamic>();
    } catch (_) {
      // 兼容纯 URL 推送
      json = {'action': 'push', 'url': payload};
    }
    final action = (json['action'] ?? 'push').toString();
    final url = (json['url'] ?? '').toString();
    final title = (json['title'] ?? json['name'] ?? '').toString();
    final searchWord = (json['search'] ?? json['word'] ?? '').toString();

    switch (action) {
      case 'push':
      case 'play':
        _eventController.add(RemoteEvent(
          type: 'play',
          data: url,
          extra: {'title': title, ...json},
        ));
        LOG.i('RemoteServer', '收到推送: $title -> $url');
        _ok(request, jsonEncode({'code': 200, 'msg': '已推送至播放器'}));
        break;
      case 'search':
        _eventController.add(RemoteEvent(
          type: 'search',
          data: searchWord,
        ));
        LOG.i('RemoteServer', '收到搜索: $searchWord');
        _ok(request, jsonEncode({'code': 200, 'msg': '已发起搜索'}));
        break;
      case 'url':
        _eventController.add(RemoteEvent(type: 'url', data: url));
        _ok(request, jsonEncode({'code': 200, 'msg': '已接收 URL'}));
        break;
      default:
        _ok(request, jsonEncode({'code': 400, 'msg': '未知 action: $action'}));
    }
  }

  /// /files/<path> —— 提供本地文件（clan 协议用）
  Future<void> _handleFiles(HttpRequest request) async {
    final rel = request.uri.path.substring('/files/'.length);
    if (rel.isEmpty) {
      _ok(request, '[]');
      return;
    }
    // 仅允许访问应用目录，防止越权
    final dir = await _safeRoot();
    final file = File('${dir.path}/$rel');
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      request.response.headers.contentType = ContentType.binary;
      request.response.add(bytes);
      await request.response.close();
    } catch (e) {
      LOG.e('RemoteServer', '读取文件失败 $rel', e);
      request.response.statusCode = HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  /// /status —— 返回当前配置状态
  Future<void> _handleStatus(HttpRequest request) async {
    final apiUrl =
        HawkStore.get<String>(HawkConfig.apiUrl, defaultValue: '') ?? '';
    final homeApi =
        HawkStore.get<String>(HawkConfig.homeApi, defaultValue: '') ?? '';
    _ok(request, jsonEncode({
      'code': 200,
      'version': '1.0.0',
      'api_url': apiUrl,
      'home_api': homeApi,
      'port': _port,
    }));
  }

  Future<Directory> _safeRoot() async {
    final dir = await Directory.systemTemp.createTemp('tvbox_remote');
    return dir;
  }

  void _ok(HttpRequest request, String body) {
    request.response.headers.contentType = ContentType.json;
    request.response.write(body);
    request.response.close();
  }
}
