// DLNA 投屏管理器，对应原项目 com.github.tvbox.osc.util.DLNACastManager
// 纯 dart:io 实现 SSDP 设备发现 + SOAP 投屏控制，不引入额外依赖
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/utils/log.dart';

/// DLNA 渲染设备
class DlnaDevice {
  DlnaDevice({
    required this.location,
    required this.name,
    required this.controlUrl,
    required this.avTransportUrl,
  });
  final String location; // 设备描述 URL
  final String name;
  final String controlUrl; // 控制接口（相对/绝对）
  String avTransportUrl; // 完整 AVTransport 控制地址

  @override
  String toString() => 'DlnaDevice($name @ $avTransportUrl)';
}

/// DLNA 投屏管理器（单例）
class CastManager {
  CastManager._();
  static final CastManager instance = CastManager._();

  // SSDP 多播参数
  static final InternetAddress _ssdpAddress =
      InternetAddress('239.255.255.250');
  static const int _ssdpPort = 1900;

  final List<DlnaDevice> _devices = <DlnaDevice>[];
  RawDatagramSocket? _socket;
  Timer? _discoverTimer;
  bool _searching = false;

  List<DlnaDevice> get devices => List.unmodifiable(_devices);

  /// 设备列表变化通知
  final StreamController<List<DlnaDevice>> _deviceController =
      StreamController<List<DlnaDevice>>.broadcast();
  Stream<List<DlnaDevice>> get deviceStream => _deviceController.stream;

  bool get isSearching => _searching;

  /// 开始搜索 DLNA 设备（SSDP M-SEARCH）
  Future<void> startSearch({Duration timeout = const Duration(seconds: 5)}) async {
    if (_searching) return;
    _searching = true;
    _devices.clear();
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
      _socket!.listen(_onDatagram);

      final search = _buildSearchRequest();
      _socket!.send(search, _ssdpAddress, _ssdpPort);

      _discoverTimer?.cancel();
      _discoverTimer = Timer(timeout, () {
        stopSearch();
      });
    } catch (e) {
      LOG.e('CastManager', 'SSDP 搜索失败', e);
      _searching = false;
    }
  }

  /// 停止搜索
  void stopSearch() {
    _discoverTimer?.cancel();
    _discoverTimer = null;
    _socket?.close();
    _socket = null;
    _searching = false;
  }

  List<int> _buildSearchRequest() {
    const msg = 'M-SEARCH * HTTP/1.1\r\n'
        'HOST: 239.255.255.250:1900\r\n'
        'MAN: "ssdp:discover"\r\n'
        'MX: 2\r\n'
        'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
        '\r\n';
    return utf8.encode(msg);
  }

  void _onDatagram(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final datagram = _socket?.receive();
    if (datagram == null) return;
    final msg = utf8.decode(datagram.data);
    // 解析 LOCATION
    final locMatch = RegExp(r'LOCATION:\s*(.+)', caseSensitive: false)
        .firstMatch(msg);
    if (locMatch == null) return;
    final location = locMatch.group(1)!.trim();
    _fetchDeviceDescription(location);
  }

  /// 拉取设备描述 XML，解析 controlURL
  Future<void> _fetchDeviceDescription(String location) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.getUrl(Uri.parse(location));
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      final name = _extractXmlValue(body, '<friendlyName>') ?? '未知设备';
      final controlPath = _extractServiceControlUrl(body);
      if (controlPath == null) {
        LOG.w('CastManager', '$name 无 AVTransport 服务');
        return;
      }
      final avUrl = _resolveUrl(location, controlPath);
      // 去重
      if (_devices.any((d) => d.avTransportUrl == avUrl)) return;
      final device = DlnaDevice(
        location: location,
        name: name,
        controlUrl: controlPath,
        avTransportUrl: avUrl,
      );
      _devices.add(device);
      _deviceController.add(List.unmodifiable(_devices));
      LOG.i('CastManager', '发现设备: $name');
    } catch (e) {
      LOG.e('CastManager', '设备描述拉取失败 $location', e);
    }
  }

  /// 从设备描述 XML 中提取 AVTransport 服务的 controlURL
  String? _extractServiceControlUrl(String xml) {
    // 定位 AVTransport 服务块
    final serviceRegex = RegExp(
      r'<service>[\s\S]*?<serviceType>([^<]*MediaRenderer:AVTransport[^<]*)</serviceType>[\s\S]*?<controlURL>([^<]+)</controlURL>[\s\S]*?</service>',
      caseSensitive: false,
    );
    final m = serviceRegex.firstMatch(xml);
    if (m != null) return m.group(2)!.trim();
    // 宽松匹配
    final avIdx = xml.indexOf('AVTransport');
    if (avIdx < 0) return null;
    final sub = xml.substring(avIdx);
    final ctrlMatch = RegExp(r'<controlURL>([^<]+)</controlURL>', caseSensitive: false)
        .firstMatch(sub);
    return ctrlMatch?.group(1)?.trim();
  }

  String? _extractXmlValue(String xml, String tag) {
    final start = xml.indexOf(tag);
    if (start < 0) return null;
    final begin = start + tag.length;
    final end = xml.indexOf('</', begin);
    if (end < 0) return null;
    return xml.substring(begin, end).trim();
  }

  /// 将相对 controlURL 解析为绝对地址
  String _resolveUrl(String base, String relative) {
    if (relative.toLowerCase().startsWith('http')) return relative;
    final uri = Uri.parse(base);
    final origin = '${uri.scheme}://${uri.host}:${uri.port}';
    if (relative.startsWith('/')) return '$origin$relative';
    return '$origin/$relative';
  }

  // ============== 投屏控制（SOAP） ==============

  /// 投屏：设置播放地址并播放
  Future<bool> cast(DlnaDevice device, String url, {String? title}) async {
    final ok = await _setAvTransportUri(device, url, title: title);
    if (!ok) return false;
    return _play(device);
  }

  /// SetAVTransportURI
  Future<bool> _setAvTransportUri(DlnaDevice device, String url,
      {String? title}) async {
    final meta = _buildDidlLite(url, title);
    final body = _soapEnvelope(
      service: 'urn:schemas-upnp-org:service:AVTransport:1',
      action: 'SetAVTransportURI',
      args: [
        {'name': 'InstanceID', 'value': '0'},
        {'name': 'CurrentURI', 'value': _escapeXml(url)},
        {'name': 'CurrentURIMetaData', 'value': _escapeXml(meta)},
      ],
    );
    return _sendSoap(device, 'SetAVTransportURI', body);
  }

  /// 播放
  Future<bool> play(DlnaDevice device) => _play(device);

  Future<bool> _play(DlnaDevice device) async {
    final body = _soapEnvelope(
      service: 'urn:schemas-upnp-org:service:AVTransport:1',
      action: 'Play',
      args: [
        {'name': 'InstanceID', 'value': '0'},
        {'name': 'Speed', 'value': '1'},
      ],
    );
    return _sendSoap(device, 'Play', body);
  }

  /// 暂停
  Future<bool> pause(DlnaDevice device) async {
    final body = _soapEnvelope(
      service: 'urn:schemas-upnp-org:service:AVTransport:1',
      action: 'Pause',
      args: [
        {'name': 'InstanceID', 'value': '0'},
      ],
    );
    return _sendSoap(device, 'Pause', body);
  }

  /// 停止
  Future<bool> stop(DlnaDevice device) async {
    final body = _soapEnvelope(
      service: 'urn:schemas-upnp-org:service:AVTransport:1',
      action: 'Stop',
      args: [
        {'name': 'InstanceID', 'value': '0'},
      ],
    );
    return _sendSoap(device, 'Stop', body);
  }

  /// Seek（支持 REL_TIME / TRACK_NR）
  Future<bool> seek(DlnaDevice device, String target,
      {String unit = 'REL_TIME'}) async {
    final body = _soapEnvelope(
      service: 'urn:schemas-upnp-org:service:AVTransport:1',
      action: 'Seek',
      args: [
        {'name': 'InstanceID', 'value': '0'},
        {'name': 'Unit', 'value': unit},
        {'name': 'Target', 'value': target},
      ],
    );
    return _sendSoap(device, 'Seek', body);
  }

  /// 发送 SOAP 请求
  Future<bool> _sendSoap(
      DlnaDevice device, String actionName, String body) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.postUrl(Uri.parse(device.avTransportUrl));
      req.headers.contentType = ContentType(
        'text',
        'xml',
        charset: 'utf-8',
      );
      req.headers.set('SOAPAction',
          '"urn:schemas-upnp-org:service:AVTransport:1#$actionName"');
      req.write(body);
      final resp = await req.close();
      final code = resp.statusCode;
      client.close();
      LOG.i('CastManager', 'SOAP $actionName -> $code');
      return code >= 200 && code < 300;
    } catch (e) {
      LOG.e('CastManager', 'SOAP $actionName 失败', e);
      return false;
    }
  }

  /// 构建 SOAP 信封
  String _soapEnvelope({
    required String service,
    required String action,
    required List<Map<String, String>> args,
  }) {
    final buf = StringBuffer(
        '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/"'
        ' s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:$action xmlns:u="$service">');
    for (final a in args) {
      buf.write('<${a['name']}>${a['value']}</${a['name']}>');
    }
    buf.write('</u:$action></s:Body></s:Envelope>');
    return buf.toString();
  }

  /// 构建 DIDL-Lite 元数据
  String _buildDidlLite(String url, String? title) {
    final t = _escapeXml(title ?? 'TVBox');
    return '<DIDL-Lite xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"'
        ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
        ' xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/">'
        '<item id="1" parentID="0" restricted="1">'
        '<dc:title>$t</dc:title>'
        '<upnp:class>object.item.videoItem</upnp:class>'
        '<res protocolInfo="http-get:*:video/mp4:*">$url</res>'
        '</item></DIDL-Lite>';
  }

  String _escapeXml(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
