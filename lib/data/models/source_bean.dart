// 站点源，对应原项目 com.github.tvbox.osc.bean.SourceBean
class SourceBean {
  SourceBean({
    this.key = '',
    this.name = '',
    this.api = '',
    this.type = 0, // 0 xml 1 json 3 Spider
    this.searchable = 1,
    this.quickSearch = 1,
    this.filterable = 0,
    this.playerUrl = '',
    this.ext = '',
    this.jar = '',
    List<String>? categories,
    this.playerType = -1, // 0 system 1 ijk 2 exo 10 mxplayer -1 跟随设置
    this.timeout = 0,
    this.clickSelector = '',
    this.style = '',
  }) : categories = categories ?? <String>[];

  String key;
  String name;
  String api;
  int type; // 0 xml 1 json 3 Spider
  int searchable; // 是否可搜索
  int quickSearch; // 是否可快速搜索
  int filterable; // 是否可站点选择
  String playerUrl; // 站点解析 Url
  String ext; // 扩展数据
  String jar; // 自定义 jar
  List<String> categories; // 分类&排序
  int playerType; // 0 system 1 ijk 2 exo 10 mxplayer -1 跟随设置
  int timeout; // 站点播放信息获取超时（秒）
  String clickSelector; // 嗅探站点 selector
  String style; // 展示风格

  bool get isSearchable => searchable != 0;
  bool get isQuickSearch => quickSearch != 0;

  int get playTimeoutSeconds =>
      timeout > 0 ? timeout.clamp(5, 60) : 15;

  /// 从 JSON 站点配置项构造（cms 配置文件中的 sites 数组项）
  factory SourceBean.fromJson(Map<String, dynamic> json) {
    return SourceBean(
      key: (json['key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      api: (json['api'] ?? '').toString(),
      type: (json['type'] is int)
          ? json['type'] as int
          : int.tryParse('${json['type']}') ?? 0,
      searchable: _asInt(json['searchable'], 1),
      quickSearch: _asInt(json['quickSearch'], 1),
      filterable: _asInt(json['filterable'], 0),
      playerUrl: (json['playerUrl'] ?? '').toString(),
      ext: json['ext'] == null ? '' : json['ext'].toString(),
      jar: (json['jar'] ?? '').toString(),
      categories: (json['categories'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      playerType: _asInt(json['playerType'], -1),
      timeout: _asInt(json['timeout'], 0),
      clickSelector: (json['clickSelector'] ?? '').toString(),
      style: (json['style'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'name': name,
        'api': api,
        'type': type,
        'searchable': searchable,
        'quickSearch': quickSearch,
        'filterable': filterable,
        'playerUrl': playerUrl,
        'ext': ext,
        'jar': jar,
        'categories': categories,
        'playerType': playerType,
        'timeout': timeout,
        'clickSelector': clickSelector,
        'style': style,
      };

  static int _asInt(Object? v, int def) {
    if (v == null) return def;
    if (v is int) return v;
    return int.tryParse('$v') ?? def;
  }
}
