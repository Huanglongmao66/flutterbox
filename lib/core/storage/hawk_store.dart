// KV 存储封装，对应原项目 com.orhanobut.hawk.Hawk
// 基于 Hive 实现，支持 String/int/double/bool/List/Map
import 'dart:convert';

import 'package:hive/hive.dart';

import '../utils/log.dart';

class HawkStore {
  HawkStore._();

  static const String _boxName = 'tvbox_hawk';
  static Box? _box;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    final b = _box;
    if (b == null) {
      throw StateError('HawkStore 未初始化，请先调用 HawkStore.init()');
    }
    return b;
  }

  static bool contains(String key) => _b.containsKey(key);

  static T? get<T>(String key, {T? defaultValue}) {
    try {
      final raw = _b.get(key);
      if (raw == null) return defaultValue;
      if (raw is T) return raw;
      // 兼容 JSON 字符串存储的对象
      if (T == Map || T == List) {
        return json.decode(raw as String) as T?;
      }
      return raw as T;
    } catch (e) {
      LOG.e('HawkStore', 'get($key) 失败', e);
      return defaultValue;
    }
  }

  static Future<void> put<T>(String key, T value) async {
    try {
      if (value is Map || value is List) {
        await _b.put(key, json.encode(value));
      } else {
        await _b.put(key, value);
      }
    } catch (e) {
      LOG.e('HawkStore', 'put($key) 失败', e);
    }
  }

  static Future<void> delete(String key) async {
    try {
      await _b.delete(key);
    } catch (e) {
      LOG.e('HawkStore', 'delete($key) 失败', e);
    }
  }

  static Future<void> clear() async {
    await _b.clear();
  }
}
