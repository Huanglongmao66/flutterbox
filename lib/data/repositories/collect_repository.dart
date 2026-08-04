// 收藏仓库，对应原项目 CollectRepository + Room collect 表
// 基于 HawkStore (Hive) 存储，按 updateTime 倒序
import '../../core/storage/hawk_store.dart';
import '../models/collect_record.dart';
import 'history_repository.dart' show HistoryKeys;

class CollectRepository {
  CollectRepository._();
  static final CollectRepository instance = CollectRepository._();

  List<CollectRecord> _cache = <CollectRecord>[];

  Future<void> init() async {
    _cache = _readAll();
  }

  List<CollectRecord> get all => List.unmodifiable(_cache);

  CollectRecord? get(String sourceKey, String vodId) {
    final id = CollectRecord.buildId(sourceKey, vodId);
    for (final r in _cache) {
      if (r.id == id) return r;
    }
    return null;
  }

  bool exists(String sourceKey, String vodId) =>
      get(sourceKey, vodId) != null;

  Future<void> upsert(CollectRecord record) async {
    final id = record.id;
    _cache.removeWhere((r) => r.id == id);
    _cache.insert(0, record);
    await _writeAll();
  }

  Future<void> remove(String sourceKey, String vodId) async {
    final id = CollectRecord.buildId(sourceKey, vodId);
    _cache.removeWhere((r) => r.id == id);
    await _writeAll();
  }

  Future<void> removeById(String id) async {
    _cache.removeWhere((r) => r.id == id);
    await _writeAll();
  }

  Future<void> clear() async {
    _cache.clear();
    await _writeAll();
  }

  List<CollectRecord> _readAll() {
    final raw = HawkStore.get<List>(HistoryKeys.collectRecords);
    if (raw == null) return <CollectRecord>[];
    try {
      return raw
          .map((e) => CollectRecord.fromMap(
              (e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})))
          .where((r) => r.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.updateTime.compareTo(a.updateTime));
    } catch (_) {
      return <CollectRecord>[];
    }
  }

  Future<void> _writeAll() async {
    await HawkStore.put(
        HistoryKeys.collectRecords, _cache.map((r) => r.toMap()).toList());
  }
}
