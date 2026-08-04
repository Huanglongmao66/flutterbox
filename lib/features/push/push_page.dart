// 推送页，对应原项目 com.github.tvbox.osc.ui.activity.PushActivity
// 显示远程推送历史、远程控制服务状态
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/log.dart';
import '../../routes/app_router.dart';
import '../../services/remote_server.dart';
import 'push_service.dart';

class PushPage extends StatefulWidget {
  const PushPage({super.key});

  @override
  State<PushPage> createState() => _PushPageState();
}

class _PushPageState extends State<PushPage> {
  final PushService _service = PushService.instance;
  final RemoteServer _remote = RemoteServer.instance;
  StreamSubscription<PushRecord>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _service.events.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = _service.history;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('推送'),
        actions: [
          IconButton(
            tooltip: '清空',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () {
              _service.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusCard(),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: history.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_download, size: 56, color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text('暂无推送记录',
                            style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                        SizedBox(height: 6),
                        Text('使用远程控制推送内容到此处',
                            style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: history.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, i) {
                      final r = history[i];
                      return ListTile(
                        leading: Icon(
                          r.type == 'search'
                              ? Icons.search
                              : Icons.play_circle_outline,
                          color: AppColors.accent,
                        ),
                        title: Text(
                          r.title.isNotEmpty ? r.title : r.data,
                          style: const TextStyle(color: AppColors.text, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_typeLabel(r.type)} · ${_fmtTime(r.time)}',
                          style: const TextStyle(
                              color: AppColors.textHint, fontSize: 11),
                        ),
                        onTap: () => _onTap(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 远程控制服务状态卡片
  Widget _buildStatusCard() {
    final running = _remote.isRunning;
    final port = _remote.port;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            running ? Icons.wifi : Icons.wifi_off,
            color: running ? AppColors.accent : AppColors.pink,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? '远程控制服务运行中' : '远程控制服务未启动',
                  style: TextStyle(
                    color: running ? AppColors.accent : AppColors.pink,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  running ? '地址: 本机IP:$port' : '请检查端口占用或权限',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: running ? '停止' : '启动',
            icon: Icon(
              running ? Icons.stop_circle_outlined : Icons.play_circle_outline,
              color: running ? AppColors.pink : AppColors.accent,
            ),
            onPressed: () async {
              try {
                if (running) {
                  await _remote.stop();
                } else {
                  await _remote.start();
                }
                setState(() {});
              } catch (e) {
                LOG.e('PushPage', '切换远程服务失败', e);
              }
            },
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'play':
        return '推送播放';
      case 'search':
        return '远程搜索';
      case 'url':
        return 'URL';
      default:
        return type;
    }
  }

  String _fmtTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${t.month}-${t.day} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _onTap(PushRecord r) {
    if (r.type == 'search') {
      context.push(AppRoutes.search);
    } else {
      // 推送播放 / URL → 进播放器
      context.push(AppRoutes.player, extra: {
        'title': r.title.isNotEmpty ? r.title : '推送',
        'url': r.data,
      });
    }
  }
}
