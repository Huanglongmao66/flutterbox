// 首页，对应原项目 com.github.tvbox.osc.ui.activity.HomeActivity
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/focus/tv_focus.dart';
import '../../core/theme/app_theme.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/vod_card.dart';
import 'home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late HomeViewModel _vm;
  final ScrollController _gridScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = HomeViewModel();
    _vm.init();
    _gridScroll.addListener(_onGridScroll);
  }

  @override
  void dispose() {
    _gridScroll.removeListener(_onGridScroll);
    _gridScroll.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _onGridScroll() {
    if (_gridScroll.position.pixels >= _gridScroll.position.maxScrollExtent - 200) {
      _vm.loadCategory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Consumer<HomeViewModel>(
          builder: (context, vm, _) {
            if (vm.state == HomeLoadState.idle ||
                vm.state == HomeLoadState.loading) {
              return const LoadingState(tip: '正在加载站点配置...');
            }
            if (vm.state == HomeLoadState.empty) {
              return EmptyState(
                tip: '未配置站点源',
                icon: Icons.cloud_off,
              );
            }
            if (vm.state == HomeLoadState.error) {
              return ErrorState(msg: vm.errorMsg, onRetry: () => vm.reload());
            }
            return _buildBody(vm);
          },
        ),
      ),
    );
  }

  Widget _buildBody(HomeViewModel vm) {
    return Column(
      children: [
        _buildTopBar(vm),
        _buildClassNav(vm),
        Expanded(child: _buildContent(vm)),
      ],
    );
  }

  // 顶栏：标题 + 日期 + 功能入口
  Widget _buildTopBar(HomeViewModel vm) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        ' ${['周一', '周二', '周三', '周四', '周五', '周六', '周日'][now.weekday - 1]}';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      color: AppColors.background,
      child: Row(
        children: [
          const Text(
            AppConstants.appName,
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Text(dateStr, style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
          const Spacer(),
          _topAction(Icons.search, '搜索', () => context.push(AppRoutes.search)),
          _topAction(Icons.live_tv, '直播', () => context.push(AppRoutes.live)),
          _topAction(Icons.history, '历史', () => context.push(AppRoutes.history)),
          _topAction(Icons.favorite_outline, '收藏', () => context.push(AppRoutes.collect)),
          _topAction(Icons.folder_open, '本地', () => context.push(AppRoutes.local)),
          _topAction(Icons.cloud_upload, '推送', () => context.push(AppRoutes.push)),
          _topAction(Icons.settings, '设置', () async {
            await context.push(AppRoutes.settings);
            // 设置页可能改了源，回来后重新加载
            vm.reload();
          }),
        ],
      ),
    );
  }

  Widget _topAction(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: TvIconButton(
        icon: icon,
        label: label,
        onTap: onTap,
      ),
    );
  }

  // 分类导航
  Widget _buildClassNav(HomeViewModel vm) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: vm.classes.length,
        itemBuilder: (context, index) {
          final sort = vm.classes[index];
          final selected = index == vm.selectedClassIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TvNavChip(
              label: sort.name,
              selected: selected,
              onTap: () => vm.selectClass(index),
            ),
          );
        },
      ),
    );
  }

  // 内容区：首页推荐 或 分类网格
  Widget _buildContent(HomeViewModel vm) {
    if (vm.selectedClassIndex == 0) {
      return _buildRecommend(vm);
    }
    return _buildCategoryGrid(vm);
  }

  Widget _buildRecommend(HomeViewModel vm) {
    if (vm.recommend.isEmpty) {
      return const EmptyState(tip: '暂无推荐内容');
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: vm.recommend.length,
      itemBuilder: (context, index) {
        final v = vm.recommend[index];
        return VodCard(
          video: v,
          onTap: () => _goDetail(v.sourceKey.isEmpty
              ? (vm.source?.key ?? '')
              : v.sourceKey, v.id, v.name),
        );
      },
    );
  }

  Widget _buildCategoryGrid(HomeViewModel vm) {
    if (vm.categoryState == HomeLoadState.loading && vm.categoryList.isEmpty) {
      return const LoadingState();
    }
    if (vm.categoryState == HomeLoadState.empty) {
      return const EmptyState(tip: '该分类暂无内容');
    }
    if (vm.categoryState == HomeLoadState.error) {
      return ErrorState(msg: vm.errorMsg, onRetry: () => vm.loadCategory(refresh: true));
    }
    return GridView.builder(
      controller: _gridScroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemCount: vm.categoryList.length + (vm.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= vm.categoryList.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            ),
          );
        }
        final v = vm.categoryList[index];
        return VodCard(
          video: v,
          onTap: () => _goDetail(
              v.sourceKey.isEmpty ? (vm.source?.key ?? '') : v.sourceKey,
              v.id,
              v.name),
        );
      },
    );
  }

  void _goDetail(String sourceKey, String vodId, String title) {
    context.push(AppRoutes.detail, extra: {
      'sourceKey': sourceKey,
      'vodId': vodId,
      'title': title,
    });
  }
}
