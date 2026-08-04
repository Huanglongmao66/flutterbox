// 分类，对应原项目 com.github.tvbox.osc.bean.MovieSort
class MovieSort {
  MovieSort({List<SortData>? sortList}) : sortList = sortList ?? <SortData>[];

  List<SortData> sortList;
}

class SortData {
  SortData({
    this.id = '',
    this.name = '',
    this.sort = -1,
    this.select = false,
    List<SortFilter>? filters,
    Map<String, String>? filterSelect,
    this.flag = '',
  })  : filters = filters ?? <SortFilter>[],
        filterSelect = filterSelect ?? <String, String>{};

  String id;
  String name;
  int sort;
  bool select;
  List<SortFilter> filters;
  Map<String, String> filterSelect;
  String flag;

  int get filterSelectCount =>
      filterSelect.values.where((v) => v.isNotEmpty).length;

  factory SortData.fromJson(Map<String, dynamic> json) {
    return SortData(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sort: int.tryParse('${json['sort'] ?? -1}') ?? -1,
      flag: (json['flag'] ?? '').toString(),
    );
  }
}

class SortFilter {
  SortFilter({this.key = '', this.name = '', Map<String, String>? values})
      : values = values ?? <String, String>{};

  String key;
  String name;
  Map<String, String> values; // key -> 显示名
}
