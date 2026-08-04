// 弹幕加载器，对应原项目 DanmuHelper
// 解析弹幕 XML（B 站格式）与 JSON 格式
import 'dart:convert';

import '../../core/network/http_client.dart';
import '../../core/utils/log.dart';
import 'danmu_item.dart';

class DanmuLoader {
  DanmuLoader._();
  static final DanmuLoader instance = DanmuLoader._();

  /// 从 URL 加载弹幕（自动识别 XML/JSON）
  Future<List<DanmuItem>> loadFromUrl(String url,
      {Map<String, dynamic>? query}) async {
    if (url.isEmpty) return <DanmuItem>[];
    try {
      final body = await HttpClient.get(url, query: query);
      if (body.isEmpty) return <DanmuItem>[];
      if (body.contains('<')) {
        return parseXml(body);
      }
      return parseJson(body);
    } catch (e) {
      LOG.e('Danmu', '加载弹幕失败：$url', e);
      return <DanmuItem>[];
    }
  }

  /// 解析 B 站弹幕 XML
  /// <d p="time,mode,color,size,?,timestamp,pool,user,origId">text</d>
  List<DanmuItem> parseXml(String body) {
    final items = <DanmuItem>[];
    final reg = RegExp(r'<d\s+[^>]*p="([^"]*)"[^>]*>([^<]*)</d>');
    for (final m in reg.allMatches(body)) {
      try {
        final attrs = m.group(1)!.split(',');
        if (attrs.length < 4) continue;
        final time = (double.tryParse(attrs[0]) ?? 0) * 1000;
        final mode = _modeFromCode(int.tryParse(attrs[1]) ?? 1);
        final color = int.tryParse(attrs[2]) ?? 0xFFFFFF;
        final size = int.tryParse(attrs[3]) ?? 25;
        final text = m.group(2) ?? '';
        if (text.isEmpty) continue;
        items.add(DanmuItem(
          time: time.round(),
          text: text,
          color: color,
          mode: mode,
          size: size,
        ));
      } catch (_) {}
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  /// 解析 JSON 弹幕
  /// [{"time":1.0,"mode":1,"color":16777215,"text":"..."}]
  List<DanmuItem> parseJson(String body) {
    final items = <DanmuItem>[];
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List) return items;
      for (final e in decoded) {
        if (e is! Map) continue;
        final text = (e['text'] ?? e['content'] ?? '').toString();
        if (text.isEmpty) continue;
        items.add(DanmuItem(
          time: ((e['time'] ?? e['ts'] ?? 0) is num
                  ? (e['time'] ?? e['ts']) as num
                  : num.tryParse('${e['time'] ?? e['ts'] ?? 0}') ?? 0)
              .toDouble()
              .round(),
          text: text,
          color: (e['color'] is int
              ? e['color'] as int
              : int.tryParse('${e['color'] ?? 0xFFFFFF}') ?? 0xFFFFFF),
          mode: _modeFromCode((e['mode'] ?? 1) is int
              ? e['mode'] as int
              : int.tryParse('${e['mode'] ?? 1}') ?? 1),
          size: (e['size'] is int ? e['size'] as int : 25),
        ));
      }
    } catch (e) {
      LOG.e('Danmu', 'JSON 弹幕解析失败', e);
    }
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }

  DanmuMode _modeFromCode(int code) {
    switch (code) {
      case 4:
      case 5:
        return DanmuMode.bottom;
      case 1:
      case 2:
      case 3:
        return DanmuMode.top;
      default:
        return DanmuMode.scroll;
    }
  }
}
