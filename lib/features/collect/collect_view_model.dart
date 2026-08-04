// 收藏 ViewModel，对应原项目 CollectActivity 的数据逻辑
import 'package:flutter/foundation.dart';

import '../../data/models/collect_record.dart';
import '../../data/repositories/collect_repository.dart';

enum CollectLoadState { idle, loading, loaded, empty }

class CollectViewModel extends ChangeNotifier {
  CollectViewModel();

  CollectLoadState _state = CollectLoadState.idle;
  List<CollectRecord> _records = <CollectRecord>[];
  String _keyword = '';

  CollectLoadState get state => _state;
  List<CollectRecord> get records => _records;
  String get keyword => _keyword;

  List<CollectRecord> get filtered {
    if (_keyword.isEmpty) return _records;
    final kw = _keyword.toLowerCase();
    return _records
        .where((r) => r.name.toLowerCase().contains(kw))
        .toList();
  }

  Future<void> refresh() async {
    _state = CollectLoadState.loading;
    notifyListeners();
    _records = CollectRepository.instance.all;
    _state = _records.isEmpty ? CollectLoadState.empty : CollectLoadState.loaded;
    notifyListeners();
  }

  void setKeyword(String kw) {
    _keyword = kw;
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await CollectRepository.instance.removeById(id);
    await refresh();
  }

  Future<void> clearAll() async {
    await CollectRepository.instance.clear();
    await refresh();
  }
}
