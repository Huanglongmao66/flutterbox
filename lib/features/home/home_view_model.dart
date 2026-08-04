// 首页 ViewModel，对应原项目 HomeActivity + SourceViewModel 的首页逻辑
import 'package:flutter/foundation.dart';

import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/source_repository.dart';

enum HomeLoadState { idle, loading, loaded, empty, error }

class HomeViewModel extends ChangeNotifier {
  HomeViewModel();

  HomeLoadState _state = HomeLoadState.idle;
  String _errorMsg = '';

  SourceBean? _source;
  List<SortData> _classes = [];
  List<MovieVideo> _recommend = [];
  int _selectedClassIndex = 0;

  // 分类网格数据
  final Map<int, MoviePage> _categoryCache = {};
  HomeLoadState _categoryState = HomeLoadState.idle;
  List<MovieVideo> _categoryList = [];
  int _categoryPage = 1;
  int _categoryPageCount = 1;
  bool _categoryLoadingMore = false;

  HomeLoadState get state => _state;
  HomeLoadState get categoryState => _categoryState;
  String get errorMsg => _errorMsg;
  SourceBean? get source => _source;
  List<SortData> get classes => _classes;
  List<MovieVideo> get recommend => _recommend;
  int get selectedClassIndex => _selectedClassIndex;
  List<MovieVideo> get categoryList => _categoryList;
  bool get hasMore => _categoryPage < _categoryPageCount;
  bool get categoryLoadingMore => _categoryLoadingMore;

  /// 初始化：加载配置 + 首页
  Future<void> init() async {
    if (ApiConfig.instance.homeSource == null) {
      _state = HomeLoadState.empty;
      notifyListeners();
      return;
    }
    _state = HomeLoadState.loading;
    notifyListeners();
    try {
      _source = ApiConfig.instance.homeSource;
      final result = await SourceRepository.instance.homeContent(_source!);
      _classes = result.classes;
      _recommend = result.recommend;
      // 添加"首页"虚拟分类
      if (_recommend.isNotEmpty) {
        _classes.insert(0, SortData(id: 'home', name: '首页'));
      }
      _state = _recommend.isEmpty && _classes.isEmpty
          ? HomeLoadState.empty
          : HomeLoadState.loaded;
      if (_classes.isNotEmpty) {
        _selectedClassIndex = 0;
      }
      _errorMsg = '';
    } catch (e) {
      _state = HomeLoadState.error;
      _errorMsg = '$e';
    }
    notifyListeners();
  }

  /// 重新加载配置后刷新
  Future<void> reload() async {
    _categoryCache.clear();
    _categoryList = [];
    _recommend = [];
    _classes = [];
    _selectedClassIndex = 0;
    await init();
  }

  void selectClass(int index) {
    if (index == _selectedClassIndex) return;
    _selectedClassIndex = index;
    notifyListeners();
    if (index > 0) {
      _categoryList = [];
      _categoryState = HomeLoadState.loading;
      notifyListeners();
      loadCategory(refresh: true);
    } else {
      _categoryState = HomeLoadState.idle;
      notifyListeners();
    }
  }

  Future<void> loadCategory({bool refresh = false}) async {
    if (_source == null) return;
    if (_selectedClassIndex <= 0) return;
    if (_categoryLoadingMore) return;
    final sort = _classes[_selectedClassIndex];
    if (refresh) {
      _categoryPage = 1;
      _categoryList = [];
    } else if (!hasMore) {
      return;
    }
    if (refresh) {
      _categoryState = HomeLoadState.loading;
    } else {
      _categoryLoadingMore = true;
    }
    notifyListeners();
    try {
      final page = await SourceRepository.instance
          .categoryContent(_source!, sort, _categoryPage);
      if (refresh) {
        _categoryList = page.videoList;
      } else {
        _categoryList = [..._categoryList, ...page.videoList];
      }
      _categoryPageCount = page.pagecount > 0 ? page.pagecount : 1;
      _categoryState =
          _categoryList.isEmpty ? HomeLoadState.empty : HomeLoadState.loaded;
      if (_categoryState == HomeLoadState.loaded && hasMore) {
        _categoryPage++;
      }
    } catch (e) {
      _categoryState = HomeLoadState.error;
      _errorMsg = '$e';
    }
    _categoryLoadingMore = false;
    notifyListeners();
  }
}
