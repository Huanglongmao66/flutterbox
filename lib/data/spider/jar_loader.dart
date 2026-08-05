// JarLoader：下载、缓存 JAR/ZIP 文件，提取 JS 脚本
// 现代 TVBox Spider JAR 通常为 ZIP 格式，内含 js/<ClassName>.js 脚本
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/network/http_client.dart';
import '../../core/utils/log.dart';

class JarLoader {
  JarLoader._();
  static final JarLoader instance = JarLoader._();

  final Map<String, String> _jsCache = {}; // jarUrl -> 解压目录路径
  final Set<String> _compiledJars = {}; // 已知的编译型 JAR URL（含 classes.dex，无 JS）
  String _globalJar = '';

  void setGlobalJar(String jar) {
    if (jar != _globalJar) {
      _globalJar = jar;
      _jsCache.clear();
      _compiledJars.clear();
    }
  }

  String get globalJar => _globalJar;

  /// 同步检查：JAR URL 是否已知为编译型（含 classes.dex，无 JS）
  /// 首次需通过 getJsFromJar 或 preCheckJar 异步检测后才会缓存
  bool isKnownCompiled(String rawUrl) {
    final url = _cleanJarUrl(rawUrl);
    return _compiledJars.contains(url);
  }

  /// 获取 JAR 中指定类名对应的 JS 脚本
  /// [className] 如 "csp_NewErXiaoGuard"
  /// [jarUrl] 优先使用站点级 jar URL，为空则用全局 spider jar
  Future<String> getJsFromJar(String className, {String? jarUrl}) async {
    final rawUrl = (jarUrl?.isNotEmpty == true) ? jarUrl! : _globalJar;
    if (rawUrl.isEmpty || className.isEmpty) return '';

    // 清理 URL 中的 ;md5;xxx 校验后缀
    final url = _cleanJarUrl(rawUrl);

    try {
      final dirPath = await _ensureExtracted(url);
      if (dirPath == null) return '';

      // 在解压目录中查找匹配的 JS 文件
      // 常见路径模式：js/<className>.js, <className>.js
      final fileName = '$className.js';
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return '';

      // 优先精确匹配
      final candidates = <File>[];
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.js')) {
          final name = entity.uri.pathSegments.last;
          if (name == fileName) {
            candidates.insert(0, entity); // 精确匹配优先
          } else if (name.toLowerCase() == fileName.toLowerCase()) {
            candidates.add(entity);
          }
        }
      }

      if (candidates.isNotEmpty) {
        final js = await candidates.first.readAsString(encoding: utf8);
        LOG.i('JarLoader', '从 JAR 提取 JS: $className (${candidates.first.path})');
        return js;
      }

      // 尝试直接读取 js/ 目录下的同名文件
      final directPath = '$dirPath/js/$fileName';
      final directFile = File(directPath);
      if (directFile.existsSync()) {
        final js = await directFile.readAsString(encoding: utf8);
        LOG.i('JarLoader', '从 JAR 提取 JS: $className ($directPath)');
        return js;
      }

      LOG.w('JarLoader', 'JAR 中未找到 $className 对应的 JS 脚本');
      return '';
    } catch (e) {
      LOG.e('JarLoader', '从 JAR 提取 JS 失败: $className', e);
      return '';
    }
  }

  /// 下载并解压 JAR，返回解压目录路径
  Future<String?> _ensureExtracted(String jarUrl) async {
    if (_jsCache.containsKey(jarUrl)) {
      final cached = _jsCache[jarUrl]!;
      if (Directory(cached).existsSync()) return cached;
    }

    try {
      LOG.i('JarLoader', '下载 JAR: $jarUrl');
      final bytes = await HttpClient.getBytes(jarUrl);
      if (bytes.isEmpty) {
        LOG.w('JarLoader', 'JAR 下载为空: $jarUrl');
        return null;
      }

      // 尝试作为 ZIP 解压
      Archive? archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        // 不是 ZIP，可能是直接 JS 文件
        final jsContent = utf8.decode(bytes, allowMalformed: true);
        if (jsContent.contains('function') || jsContent.contains('=>')) {
          // 缓存为单文件
          final cacheDir = await _cacheDir(jarUrl);
          final dir = Directory(cacheDir);
          dir.createSync(recursive: true);
          final f = File('${dir.path}/__direct.js');
          await f.writeAsString(jsContent);
          _jsCache[jarUrl] = cacheDir;
          LOG.i('JarLoader', 'JAR 实为 JS 文件，已缓存');
          return cacheDir;
        }
        LOG.w('JarLoader', 'JAR 既非 ZIP 也非 JS: $jarUrl');
        return null;
      }

      // 解压到缓存目录
      final cacheDir = await _cacheDir(jarUrl);
      final dir = Directory(cacheDir);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      dir.createSync(recursive: true);

      for (final file in archive) {
        if (file.isFile) {
          final outPath = '$cacheDir/${file.name}';
          final outFile = File(outPath);
          outFile.parent.createSync(recursive: true);
          outFile.writeAsBytesSync(file.content as List<int>);
        }
      }

      _jsCache[jarUrl] = cacheDir;

      // 检测是否为编译型 JAR（含 classes.dex，无 JS 脚本）
      final hasDex = File('$cacheDir/classes.dex').existsSync();
      final hasJs = await _hasJsFiles(dir);
      if (hasDex && !hasJs) {
        _compiledJars.add(jarUrl);
        LOG.w('JarLoader',
            'JAR 为编译型 Java 字节码（含 classes.dex），不含 JS 脚本，降级 JsonSpider');
      } else {
        LOG.i('JarLoader', 'JAR 解压完成: ${archive.length} 个文件 -> $cacheDir');
      }
      return cacheDir;
    } catch (e) {
      LOG.e('JarLoader', '下载/解压 JAR 失败: $jarUrl', e);
      return null;
    }
  }

  /// 生成缓存目录路径
  Future<String> _cacheDir(String jarUrl) async {
    final appDir = await getApplicationDocumentsDirectory();
    final hash = _simpleHash(jarUrl);
    return '${appDir.path}/jar_cache/$hash';
  }

  String _simpleHash(String s) {
    var h = 0;
    for (int i = 0; i < s.length; i++) {
      h = (h * 31 + s.codeUnitAt(i)) & 0x7fffffff;
    }
    return 'jar_$h';
  }

  /// 清理 JAR URL 中的校验后缀
  /// 如 "https://x.com/a.png;md5;abc123" → "https://x.com/a.png"
  String _cleanJarUrl(String url) {
    const marker = ';md5;';
    final idx = url.indexOf(marker);
    if (idx > 0) return url.substring(0, idx);
    return url;
  }

  /// 检查目录中是否包含 JS 文件
  Future<bool> _hasJsFiles(Directory dir) async {
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.js')) return true;
    }
    return false;
  }

  /// 异步预热：下载并检测 JAR 类型，缓存结果供 isKnownCompiled 同步查询
  Future<void> preCheckJar(String rawUrl) async {
    final url = _cleanJarUrl(rawUrl);
    if (url.isEmpty || _jsCache.containsKey(url) || _compiledJars.contains(url)) {
      return;
    }
    await _ensureExtracted(url);
  }

  /// 清除所有缓存
  Future<void> clearCache() async {
    _jsCache.clear();
    _compiledJars.clear();
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/jar_cache');
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }
}
