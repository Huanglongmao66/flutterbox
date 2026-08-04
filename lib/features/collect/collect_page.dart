// 收藏页，对应原项目 com.github.tvbox.osc.ui.activity.CollectActivity
// 网格展示收藏影片，点击进入详情
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/collect_record.dart';
import '../../data/models/movie.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/vod_card.dart';
import 'collect_view_model.dart';

class CollectPage extends StatefulWidget {
  const CollectPage({super.key});

  @override
  State<CollectPage> createState() => _CollectPageState();
}

class _CollectPageState extends State<CollectPage> {
  late CollectViewModel _vm;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _gridView = true;

  @override
  void initState() {
    super.initState();
    _vm = CollectViewModel();
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
            Expanded(child: Consumer<CollectViewModel>(builder: (_, vm, __) {
              if (vm.state == CollectLoadState.loading) {
                return const LoadingState(tip: '加载收藏...');
              }
              final list = vm.filtered;
              if (list.isEmpty) {
                return const EmptyState(tip: '暂无收藏', icon: Icons.favorite_border);
              }
              return _gridView ? _buildGrid(list) : _buildList(list);
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
          const Text('收藏',
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
                hintText: '搜索收藏',
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
          IconButton(
            tooltip: _gridView ? '列表视图' : '网格视图',
            icon: Icon(_gridView ? Icons.view_list : Icons.grid_view,
                color: AppColors.textSecondary, size: 20),
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          TextButton.icon(
            onPressed: _confirmClear,
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.pink, size: 18),
            label: const Text('清空', style: TextStyle(color: AppColors.pink, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<CollectRecord> list) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        final video = MovieVideo(
          id: r.vodId,
          name: r.name,
          pic: r.pic,
          note: r.note,
          sourceKey: r.sourceKey,
        );
        return VodCard(
          video: video,
          onTap: () => _goDetail(r),
        );
      },
    );
  }

  Widget _buildList(List<CollectRecord> list) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final r = list[index];
        return _CollectListItem(
          record: r,
          onTap: () => _goDetail(r),
          onDelete: () => _vm.remove(r.id),
        );
      },
    );
  }

  void _goDetail(CollectRecord r) {
    context.push(AppRoutes.detail, extra: {
      'sourceKey': r.sourceKey,
      'vodId': r.vodId,
      'title': r.name,
    });
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清空收藏', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('确定清空全部收藏？',
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

class _CollectListItem extends StatelessWidget {
  const _CollectListItem({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  final CollectRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: Color(0x22FFFFFF))),
        tileColor: AppColors.surface,
        title: Text(record.name,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            if (record.year != 0) '${record.year}',
            if (record.type.isNotEmpty) record.type,
            if (record.area.isNotEmpty) record.area,
            if (record.note.isNotEmpty) record.note,
          ].join(' / '),
          style: const TextStyle(color: AppColors.textHint, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.favorite, color: AppColors.pink, size: 18),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
