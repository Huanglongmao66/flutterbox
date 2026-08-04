// 直播频道模型，对应原项目 com.github.tvbox.osc.bean.LiveChannel
// 支持标准 TXT 格式与 M3U 格式
class LiveChannel {
  LiveChannel({
    required this.name,
    required this.urls,
    this.group = '',
    this.logo = '',
    this.tvgId = '',
    this.tvgName = '',
    this.epgUrl = '',
  });

  final String name;
  final List<LiveChannelUrl> urls;
  final String group;
  final String logo;
  final String tvgId;
  final String tvgName;
  final String epgUrl;

  int get urlCount => urls.length;
}

class LiveChannelUrl {
  LiveChannelUrl({required this.url, this.line = ''});

  final String url;
  final String line;
}

/// 频道分组
class LiveGroup {
  LiveGroup({required this.name, required this.channels});

  final String name;
  final List<LiveChannel> channels;
}
