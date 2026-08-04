// 搜索 ViewModel，对应原项目 SearchActivity + FastSearchActivity
// 支持普通搜索（逐源串行）与快速搜索（多源并发，逐条返回）
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants/hawk_config.dart';
import '../../core/storage/hawk_store.dart';
import '../../data/api/api_config.dart';
import '../../data/models/models.dart';
import '../../data/repositories/source_repository.dart';

enum SearchMode { normal, fast }

class SearchSourceResult {
  SearchSourceResult({required this.source, required this.videos, this.error});
  final SourceBean source;
  final List<MovieVideo> videos;
  final String? error;
}

class SearchViewModel extends ChangeNotifier {
  SearchViewModel();

  String _keyword = '';
  SearchMode _mode = SearchMode.fast;
  bool _searching = false;
  final List<SearchSourceResult> _results = [];
  final List<String> _history = [];
  List<SourceBean> _sources = [];

  // 源选择（哪些源参与搜索）
  final Set<String> _selectedSourceKeys = {};

  String get keyword => _keyword;
  SearchMode get mode => _mode;
  bool get searching => _searching;
  List<SearchSourceResult> get results => _results;
  List<String> get history => _history;
  List<SourceBean> get sources => _sources;
  Set<String> get selectedSourceKeys => _selectedSourceKeys;

  int get totalFound => _results.fold(0, (s, r) => s + r.videos.length);

  void init() {
    _sources = ApiConfig.instance.sources.where((s) => s.isSearchable).toList();
    // 从 Hawk 读取搜索选中源
    final saved = HawkStore.get<List>(HawkConfig.sourcesForSearch);
    if (saved != null && saved.isNotEmpty) {
      _selectedSourceKeys
          .addAll(saved.map((e) => e.toString()).where((s) => s.isNotEmpty));
    } else {
      // 默认全部选中
      _selectedSourceKeys.addAll(_sources.map((s) => s.key));
    }
    final hist = HawkStore.get<List>(HawkConfig.searchHistory);
    if (hist != null) {
      _history.addAll(hist.map((e) => e.toString()));
    }
  }

  void setMode(SearchMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggleSource(String key) {
    if (_selectedSourceKeys.contains(key)) {
      _selectedSourceKeys.remove(key);
    } else {
      _selectedSourceKeys.add(key);
    }
    HawkStore.put(
        HawkConfig.sourcesForSearch, _selectedSourceKeys.toList());
    notifyListeners();
  }

  void setKeyword(String kw) => _keyword = kw;

  /// 执行搜索
  Future<void> search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    _keyword = kw;
    _results.clear();
    _searching = true;
    notifyListeners();
    _addHistory(kw);

    final activeSources = _sources
        .where((s) => _selectedSourceKeys.contains(s.key))
        .toList();
    if (activeSources.isEmpty) {
      _searching = false;
      notifyListeners();
      return;
    }

    if (_mode == SearchMode.fast) {
      await _searchFast(activeSources, kw);
    } else {
      await _searchNormal(activeSources, kw);
    }
    _searching = false;
    notifyListeners();
  }

  /// 快速搜索：多源并发，每个源完成即更新结果
  Future<void> _searchFast(List<SourceBean> sources, String kw) async {
    await Future.wait(sources.map((s) async {
      try {
        final videos = await SourceRepository.instance
            .searchContent(s, kw, quick: true)
            .timeout(const Duration(seconds: 12), onTimeout: () => []);
        if (videos.isNotEmpty || !_searching) {
          _results.add(SearchSourceResult(source: s, videos: videos));
          notifyListeners();
        } else {
          _results.add(SearchSourceResult(source: s, videos: const [], error: '无结果'));
          notifyListeners();
        }
      } catch (e) {
        _results.add(SearchSourceResult(source: s, videos: const [], error: '$e'));
        notifyListeners();
      }
    }));
  }

  /// 普通搜索：逐源串行
  Future<void> _searchNormal(List<SourceBean> sources, String kw) async {
    for (final s in sources) {
      if (!_searching) return;
      try {
        final videos = await SourceRepository.instance
            .searchContent(s, kw, quick: false)
            .timeout(const Duration(seconds: 15), onTimeout: () => []);
        _results.add(SearchSourceResult(source: s, videos: videos));
      } catch (e) {
        _results.add(SearchSourceResult(source: s, videos: const [], error: '$e'));
      }
      notifyListeners();
    }
  }

  void stop() {
    _searching = false;
    notifyListeners();
  }

  void clearResults() {
    _results.clear();
    notifyListeners();
  }

  void _addHistory(String kw) {
    _history.remove(kw);
    _history.insert(0, kw);
    if (_history.length > 20) _history.removeLast();
    HawkStore.put(HawkConfig.searchHistory, _history);
  }

  void removeHistory(String kw) {
    _history.remove(kw);
    HawkStore.put(HawkConfig.searchHistory, _history);
    notifyListeners();
  }

  void clearHistory() {
    _history.clear();
    HawkStore.put(HawkConfig.searchHistory, _history);
    notifyListeners();
  }
}
