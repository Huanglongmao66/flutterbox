// 历史记录页，对应原项目 com.github.tvbox.osc.ui.activity.HistoryActivity
// 展示观看历史 + 继续观看 + 删除/清空
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/history_record.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';
import 'history_view_model.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late HistoryViewModel _vm;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = HistoryViewModel();
    _vm.refresh();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(child: Consumer<HistoryViewModel>(builder: (_, vm, __) {
              if (vm.state == HistoryLoadState.loading) {
                return const LoadingState(tip: '加载历史...');
              }
              final list = vm.filtered;
              if (list.isEmpty) {
                return const EmptyState(tip: '暂无观看历史', icon: Icons.history_toggle_off);
              }
              return _buildList(list);
            })),
          ],
        ),
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text('历史记录',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: '搜索历史',
                hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 18),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0x33FFFFFF)),
                    borderRadius: BorderRadius.all(Radius.circular(20))),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.focusBorder),
                    borderRadius: BorderRadius.all(Radius.circular(20))),
              ),
              onChanged: (v) => _vm.setKeyword(v),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.pink, size: 18),
            label: const Text('清空', style: TextStyle(color: AppColors.pink, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<HistoryRecord> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, index) => _HistoryItem(
        record: list[index],
        onTap: () => _play(list[index]),
        onDelete: () => _vm.remove(list[index].id),
      ),
    );
  }

  void _play(HistoryRecord r) {
    // 优先使用历史中保存的剧集 URL 直接播放；否则跳详情
    if (r.episodeUrl.isNotEmpty) {
      context.push(AppRoutes.player, extra: {
        'title': r.name,
        'url': r.episodeUrl,
        'sourceKey': r.sourceKey,
        'episodeName': r.episodeName,
        'resumeMs': r.positionMs,
      });
    } else {
      context.push(AppRoutes.detail, extra: {
        'sourceKey': r.sourceKey,
        'vodId': r.vodId,
        'title': r.name,
      });
    }
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清空历史', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('确定清空全部观看历史？',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _vm.clearAll();
              },
              child: const Text('清空', style: TextStyle(color: AppColors.pink))),
        ],
      ),
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final HistoryRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = record.durationMs > 0
        ? (record.positionMs / record.durationMs).clamp(0.0, 1.0)
        : 0.0;
    final dt = DateTime.fromMillisecondsSinceEpoch(record.updateTime);
    final timeStr = _formatTime(dt);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0x22FFFFFF)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 80,
                  height: 110,
                  child: record.pic.isEmpty
                      ? Container(
                          color: AppColors.panelLight,
                          child: const Icon(Icons.movie_outlined,
                              color: AppColors.textHint, size: 24),
                        )
                      : CachedNetworkImage(
                          imageUrl: record.pic,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: AppColors.panelLight),
                          errorWidget: (_, __, ___) => Container(
                              color: AppColors.panelLight,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textHint, size: 22)),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(record.name,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    if (record.episodeName.isNotEmpty)
                      Text('看到：${record.episodeName}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(timeStr,
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 11)),
                    if (progress > 0) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: AppColors.panelLight,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.accent),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textHint, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
