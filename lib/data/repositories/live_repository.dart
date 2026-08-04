// 直播源加载与解析，对应原项目 LiveSourceUtil + LivePlayerHelper
// 支持 TXT（频道名,#genre#）与 M3U 格式
import 'dart:async';

import '../../core/constants/hawk_config.dart';
import '../../core/network/http_client.dart';
import '../../core/storage/hawk_store.dart';
import '../../core/utils/log.dart';
import '../models/live_channel.dart';

class LiveRepository {
  LiveRepository._();
  static final LiveRepository instance = LiveRepository._();

  List<LiveGroup> _groups = <LiveGroup>[];
  List<LiveChannel> _allChannels = <LiveChannel>[];
  String _loadedUrl = '';

  List<LiveGroup> get groups => _groups;
  List<LiveChannel> get allChannels => _allChannels;
  String get loadedUrl => _loadedUrl;

  /// 加载直播源（从 HawkConfig.liveApiUrl 读取地址）
  Future<List<LiveGroup>> load() async {
    final url = HawkStore.get<String>(HawkConfig.liveApiUrl, defaultValue: '') ?? '';
    if (url.isEmpty) {
      _groups = <LiveGroup>[];
      _allChannels = <LiveChannel>[];
      return _groups;
    }
    if (_loadedUrl == url && _groups.isNotEmpty) return _groups;
    return loadFromUrl(url);
  }

  Future<List<LiveGroup>> loadFromUrl(String url) async {
    if (url.isEmpty) return _groups;
    try {
      final body = await HttpClient.get(url);
      if (body.isEmpty) {
        LOG.e('Live', '直播源为空：$url', null);
        return _groups;
      }
      _loadedUrl = url;
      if (body.contains('#EXTM3U')) {
        _groups = parseM3u(body);
      } else {
        _groups = parseTxt(body);
      }
      _allChannels = _groups.expand((g) => g.channels).toList();
      LOG.i('Live', '直播源加载完成：${_groups.length} 组 / ${_allChannels.length} 频道');
    } catch (e) {
      LOG.e('Live', '加载直播源失败', e);
      _groups = <LiveGroup>[];
      _allChannels = <LiveChannel>[];
    }
    return _groups;
  }

  /// 解析 TXT 格式
  /// 格式：
  /// 分组名,#genre#
  /// 频道1,URL1
  /// 频道2,URL2#$URL2备用
  List<LiveGroup> parseTxt(String body) {
    final groups = <LiveGroup>[];
    final map = <String, List<LiveChannel>>{};
    String currentGroup = '';

    for (final rawLine in body.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(',');
      if (parts.length < 2) continue;
      final left = parts[0].trim();
      final right = parts.sublist(1).join(',').trim();
      if (right == '#genre#') {
        currentGroup = left;
        map.putIfAbsent(currentGroup, () => <LiveChannel>[]);
        continue;
      }
      // right 可能含多个 URL，以 # 分隔（备用线路）
      final urls = <LiveChannelUrl>[];
      for (final seg in right.split('#')) {
        final s = seg.trim();
        if (s.isEmpty) continue;
        // 形如 "线路名$URL"
        final idx = s.indexOf(r'$');
        if (idx > 0) {
          urls.add(LiveChannelUrl(url: s.substring(idx + 1).trim(), line: s.substring(0, idx).trim()));
        } else {
          urls.add(LiveChannelUrl(url: s, line: ''));
        }
      }
      if (urls.isEmpty) continue;
      final channel = LiveChannel(
        name: left,
        urls: urls,
        group: currentGroup.isEmpty ? '默认分组' : currentGroup,
      );
      final g = channel.group;
      map.putIfAbsent(g, () => <LiveChannel>[]);
      // 同名频道合并
      final existing = map[g]!.lastWhere(
        (c) => c.name == channel.name,
        orElse: () => channel,
      );
      if (existing != channel) {
        existing.urls.addAll(channel.urls);
      } else {
        map[g]!.add(channel);
      }
    }

    map.forEach((name, channels) {
      groups.add(LiveGroup(name: name, channels: channels));
    });
    return groups;
  }

  /// 解析 M3U 格式
  List<LiveGroup> parseM3u(String body) {
    final groups = <LiveGroup>[];
    final map = <String, List<LiveChannel>>{};
    String currentName = '';
    String currentGroup = '';
    String currentLogo = '';
    String currentTvgId = '';
    String currentTvgName = '';

    for (final rawLine in body.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#EXTM3U')) continue;
      if (line.startsWith('#EXTINF')) {
        // #EXTINF:-1 tvg-id="x" tvg-name="y" tvg-logo="z" group-title="g",频道名
        currentName = '';
        currentGroup = '';
        currentLogo = '';
        currentTvgId = '';
        currentTvgName = '';
        final commaIdx = line.lastIndexOf(',');
        if (commaIdx > 0) {
          currentName = line.substring(commaIdx + 1).trim();
        }
        final attrs = line.substring(0, commaIdx > 0 ? commaIdx : line.length);
        currentGroup = _attr(attrs, 'group-title') ?? '';
        currentLogo = _attr(attrs, 'tvg-logo') ?? '';
        currentTvgId = _attr(attrs, 'tvg-id') ?? '';
        currentTvgName = _attr(attrs, 'tvg-name') ?? '';
        if (currentGroup.isEmpty) currentGroup = '默认分组';
        continue;
      }
      if (currentName.isEmpty) continue;
      final channel = LiveChannel(
        name: currentName,
        urls: [LiveChannelUrl(url: line, line: '')],
        group: currentGroup,
        logo: currentLogo,
        tvgId: currentTvgId,
        tvgName: currentTvgName,
      );
      map.putIfAbsent(currentGroup, () => <LiveChannel>[]);
      final existing = map[currentGroup]!.lastWhere(
        (c) => c.name == channel.name,
        orElse: () => channel,
      );
      if (existing != channel) {
        existing.urls.add(LiveChannelUrl(url: line, line: ''));
      } else {
        map[currentGroup]!.add(channel);
      }
      currentName = '';
    }

    map.forEach((name, channels) {
      groups.add(LiveGroup(name: name, channels: channels));
    });
    return groups;
  }

  String? _attr(String attrs, String key) {
    final m = RegExp('$key="([^"]*)"').firstMatch(attrs);
    return m?.group(1);
  }
}
