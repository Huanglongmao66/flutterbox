// 详情页，对应原项目 com.github.tvbox.osc.ui.activity.DetailActivity
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';
import 'detail_view_model.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({
    super.key,
    required this.sourceKey,
    required this.vodId,
    this.title = '',
  });

  final String sourceKey;
  final String vodId;
  final String title;

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late DetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = DetailViewModel();
    _vm.load(sourceKey: widget.sourceKey, vodId: widget.vodId, title: widget.title);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<DetailViewModel>(
          builder: (context, vm, _) {
            if (vm.state == DetailLoadState.loading) {
              return const LoadingState(tip: '加载详情...');
            }
            if (vm.state == DetailLoadState.error) {
              return ErrorState(msg: vm.errorMsg, onRetry: () => vm.load(
                  sourceKey: widget.sourceKey, vodId: widget.vodId, title: widget.title));
            }
            return _buildBody(vm);
          },
        ),
      ),
    );
  }

  Widget _buildBody(DetailViewModel vm) {
    final v = vm.video!;
    final info = vm.vodInfo!;
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(v, info)),
            if (vm.urlList.isNotEmpty) ...[
              SliverToBoxAdapter(child: _buildFlags(vm)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 100,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final ep = vm.episodes[index];
                      final selected = index == vm.currentEpisode;
                      return GestureDetector(
                        onTap: () {
                          vm.selectEpisode(index);
                          _play(vm, index);
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accent : AppColors.panel,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected ? AppColors.accent : const Color(0x22FFFFFF),
                            ),
                          ),
                          child: Text(
                            ep.name,
                            style: TextStyle(
                              color: selected ? AppColors.background : AppColors.textPrimary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                    childCount: vm.episodes.length,
                  ),
                ),
              ),
            ] else
              const SliverFillRemaining(
                child: EmptyState(tip: '暂无播放线路', icon: Icons.videocam_off_outlined),
              ),
          ],
        ),
        Positioned(
          top: 12,
          left: 12,
          child: _backButton(),
        ),
      ],
    );
  }

  Widget _buildHeader(MovieVideo v, VodInfo info) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(60, 24, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 130,
              height: 180,
              child: v.pic.isEmpty
                  ? Container(color: AppColors.panelLight)
                  : CachedNetworkImage(
                      imageUrl: v.pic,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.panelLight),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.panelLight,
                        child: const Icon(Icons.broken_image, color: AppColors.textHint),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        v.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _collectButton(),
                  ],
                ),
                const SizedBox(height: 10),
                _metaLine([
                  if (v.year != 0) '${v.year}',
                  if (v.area.isNotEmpty) v.area,
                  if (v.lang.isNotEmpty) v.lang,
                  if (v.type.isNotEmpty) v.type,
                ]),
                if (v.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(v.note,
                      style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                ],
                if (v.actor.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('演员：${v.actor}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (v.director.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('导演：${v.director}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _collectButton() {
    return Consumer<DetailViewModel>(
      builder: (context, vm, _) {
        return IconButton(
          tooltip: vm.collected ? '取消收藏' : '收藏',
          icon: Icon(
            vm.collected ? Icons.favorite : Icons.favorite_border,
            color: vm.collected ? AppColors.pink : AppColors.textSecondary,
            size: 24,
          ),
          onPressed: () => vm.toggleCollect(),
        );
      },
    );
  }

  Widget _metaLine(List<String> parts) {
    final text = parts.where((s) => s.isNotEmpty).join(' / ');
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(text,
        style: const TextStyle(color: AppColors.textHint, fontSize: 13));
  }

  Widget _buildFlags(DetailViewModel vm) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: vm.urlList.map((u) {
          final selected = u.flag == vm.currentFlag;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => vm.selectFlag(u.flag),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected ? AppColors.accent : const Color(0x33FFFFFF),
                  ),
                ),
                child: Text(u.flag,
                    style: TextStyle(
                      color: selected ? AppColors.background : AppColors.textPrimary,
                      fontSize: 13,
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _backButton() {
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  void _play(DetailViewModel vm, int epIndex) {
    final episodes = vm.episodes;
    if (epIndex >= episodes.length) return;
    final ep = episodes[epIndex];
    final sourceKey = vm.video?.sourceKey ?? '';
    final vodId = vm.video?.id ?? '';
    final title = vm.video?.name ?? '';
    // 记录历史（非阻塞）
    vm.selectEpisodeAndRecord(epIndex);
    context.push(AppRoutes.player, extra: {
      'title': title,
      'url': ep.url,
      'sourceKey': sourceKey,
      'vodId': vodId,
      'episodeName': ep.name,
    });
  }
}
