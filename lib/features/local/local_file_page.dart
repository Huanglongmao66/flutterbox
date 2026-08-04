// 本地文件页，对应原项目 com.github.tvbox.osc.ui.activity.LocalFileActivity
// 选择本地视频文件并播放，记录最近播放的本地文件
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../core/storage/hawk_store.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';

class LocalFilePage extends StatefulWidget {
  const LocalFilePage({super.key});

  @override
  State<LocalFilePage> createState() => _LocalFilePageState();
}

class _LocalFilePageState extends State<LocalFilePage> {
  final List<LocalVideoItem> _recent = <LocalVideoItem>[];
  final List<LocalVideoItem> _scanned = <LocalVideoItem>[];
  bool _scanning = false;
  Directory? _currentDir;

  static const String _recentKey = 'local_recent_videos';
  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'flv', 'mov', 'wmv', 'ts', 'm3u8', 'rmvb', 'rm',
    '3gp', 'webm', 'mpg', 'mpeg', 'm4v', 'f4v',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  void _loadRecent() {
    final raw = HawkStore.get<List>(_recentKey);
    if (raw == null) return;
    try {
      final list = raw
          .map((e) => LocalVideoItem.fromMap(
              e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{}))
          .where((v) => v.path.isNotEmpty)
          .toList();
      setState(() => _recent.addAll(list));
    } catch (e) {
      LOG.e('Local', '加载最近本地文件失败', e);
    }
  }

  Future<void> _saveRecent() async {
    await HawkStore.put(
        _recentKey, _recent.map((v) => v.toMap()).toList());
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _videoExtensions,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final path = f.path;
      if (path == null || path.isEmpty) return;
      _playPath(path, f.name);
    } catch (e) {
      LOG.e('Local', 'pickFiles 失败', e);
      _toast('选择文件失败：$e');
    }
  }

  Future<void> _openDirectory() async {
    try {
      final dir = await FilePicker.platform.getDirectoryPath();
      if (dir == null || dir.isEmpty) return;
      _scanDirectory(Directory(dir));
    } catch (e) {
      LOG.e('Local', 'getDirectoryPath 失败', e);
      _toast('选择目录失败：$e');
    }
  }

  Future<void> _scanDirectory(Directory dir) async {
    setState(() {
      _scanning = true;
      _currentDir = dir;
      _scanned.clear();
    });
    try {
      final items = <LocalVideoItem>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is Directory) {
          items.add(LocalVideoItem(
            path: entity.path,
            name: p.basename(entity.path),
            isDir: true,
            size: 0,
          ));
        } else if (entity is File) {
          final name = p.basename(entity.path);
          if (_isVideoFile(name)) {
            items.add(LocalVideoItem(
              path: entity.path,
              name: name,
              isDir: false,
              size: entity.lengthSync(),
            ));
          }
        }
      }
      items.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() => _scanned.addAll(items));
    } catch (e) {
      LOG.e('Local', '扫描目录失败', e);
      _toast('扫描失败：$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _playPath(String path, String name) {
    _recent.removeWhere((v) => v.path == path);
    _recent.insert(0,
        LocalVideoItem(path: path, name: name, isDir: false, size: 0));
    if (_recent.length > 50) _recent.removeLast();
    _saveRecent();
    context.push(AppRoutes.player, extra: {
      'title': name,
      'url': path,
      'sourceKey': '',
      'episodeName': '',
    });
  }

  bool _isVideoFile(String name) {
    final ext = p.extension(name).toLowerCase().replaceAll('.', '');
    return _videoExtensions.contains(ext);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildTopBar(),
          if (_currentDir != null) _buildBreadCrumb(),
          Expanded(
            child: _currentDir == null
                ? _buildHomeView()
                : _buildDirectoryView(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (_currentDir != null) {
                setState(() {
                  _currentDir = null;
                  _scanned.clear();
                });
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          const Text('本地文件',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.file_open, color: AppColors.accent, size: 18),
            label: const Text('选择文件', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          ),
          TextButton.icon(
            onPressed: _openDirectory,
            icon: const Icon(Icons.folder_open, color: AppColors.accent, size: 18),
            label: const Text('选择目录', style: TextStyle(color: AppColors.accent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadCrumb() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.folder, color: AppColors.textHint, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _currentDir!.path,
              style: const TextStyle(color: AppColors.textHint, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_scanning)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeView() {
    if (_recent.isEmpty) {
      return const EmptyState(
        tip: '点击右上角选择文件或目录',
        icon: Icons.folder_open,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            const Text('最近播放',
                style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            GestureDetector(
              onTap: () {
                setState(() => _recent.clear());
                _saveRecent();
              },
              child: const Text('清空',
                  style: TextStyle(color: AppColors.pink, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recent.map((v) => _LocalItem(
              item: v,
              onTap: () => _playPath(v.path, v.name),
              onDelete: () {
                setState(() => _recent.remove(v));
                _saveRecent();
              },
            )),
      ],
    );
  }

  Widget _buildDirectoryView() {
    if (_scanned.isEmpty && !_scanning) {
      return const EmptyState(tip: '该目录无视频文件', icon: Icons.video_library_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _scanned.length,
      itemBuilder: (context, index) {
        final item = _scanned[index];
        return _LocalItem(
          item: item,
          onTap: () {
            if (item.isDir) {
              _scanDirectory(Directory(item.path));
            } else {
              _playPath(item.path, item.name);
            }
          },
        );
      },
    );
  }
}

class LocalVideoItem {
  LocalVideoItem({
    required this.path,
    required this.name,
    required this.isDir,
    required this.size,
  });

  final String path;
  final String name;
  final bool isDir;
  final int size;

  Map<String, dynamic> toMap() => {
        'path': path,
        'name': name,
        'isDir': isDir,
        'size': size,
      };

  factory LocalVideoItem.fromMap(Map<String, dynamic> m) => LocalVideoItem(
        path: (m['path'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        isDir: m['isDir'] == true,
        size: (m['size'] is int ? m['size'] as int : 0),
      );
}

class _LocalItem extends StatelessWidget {
  const _LocalItem({required this.item, required this.onTap, this.onDelete});

  final LocalVideoItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0x22FFFFFF))),
        tileColor: AppColors.surface,
        leading: Icon(
          item.isDir ? Icons.folder : Icons.movie,
          color: item.isDir ? AppColors.accent : AppColors.textSecondary,
          size: 22,
        ),
        title: Text(item.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          item.isDir ? '文件夹' : _formatSize(item.size),
          style: const TextStyle(color: AppColors.textHint, fontSize: 11),
        ),
        trailing: onDelete != null
            ? IconButton(
                icon: const Icon(Icons.close, color: AppColors.textHint, size: 18),
                onPressed: onDelete,
              )
            : (item.isDir
                ? const Icon(Icons.chevron_right, color: AppColors.textHint)
                : const Icon(Icons.play_circle_outline, color: AppColors.accent)),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }
}
