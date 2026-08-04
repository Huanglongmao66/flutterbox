// 搜索页，对应原项目 com.github.tvbox.osc.ui.activity.SearchActivity + FastSearchActivity
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../routes/app_router.dart';
import '../../widgets/state_widgets.dart';
import '../../widgets/vod_card.dart';
import 'search_view_model.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late SearchViewModel _vm;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _vm = SearchViewModel();
    _vm.init();
    _vm.addListener(_onVmChanged);
  }

  void _onVmChanged() => setState(() {});

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _ctrl.dispose();
    _inputFocus.dispose();
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  // 左侧：搜索框 + 模式 + 源选择 + 历史
  Widget _buildSidebar() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: Color(0x33FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _ctrl,
            focusNode: _inputFocus,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '输入影片名称',
              hintStyle: const TextStyle(color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search, color: AppColors.textHint, size: 20),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Color(0x33FFFFFF)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.focusBorder),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            onSubmitted: (v) => _doSearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _modeChip('快速搜索', SearchMode.fast),
              const SizedBox(width: 8),
              _modeChip('普通搜索', SearchMode.normal),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('搜索源',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showSourceSelector(),
                child: const Text('选择',
                    style: TextStyle(color: AppColors.accent, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _vm.results.isEmpty && _vm.history.isNotEmpty && !_vm.searching
                ? _buildHistory()
                : _buildSourceStatus(),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(String label, SearchMode mode) {
    final selected = _vm.mode == mode;
    return GestureDetector(
      onTap: () => _vm.setMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.accent : const Color(0x33FFFFFF),
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? AppColors.background : AppColors.textSecondary,
              fontSize: 12,
            )),
      ),
    );
  }

  Widget _buildHistory() {
    return ListView(
      children: [
        Row(
          children: [
            const Text('搜索历史',
                style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            const Spacer(),
            GestureDetector(
              onTap: () => _vm.clearHistory(),
              child: const Icon(Icons.delete_outline,
                  color: AppColors.textHint, size: 16),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _vm.history
              .map((h) => GestureDetector(
                    onLongPress: () => _vm.removeHistory(h),
                    onTap: () {
                      _ctrl.text = h;
                      _doSearch();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.panel,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(h,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSourceStatus() {
    if (_vm.results.isEmpty && !_vm.searching) {
      return const Center(
        child: Text('输入关键词开始搜索',
            style: TextStyle(color: AppColors.textHint, fontSize: 13)),
      );
    }
    return ListView.builder(
      itemCount: _vm.results.length,
      itemBuilder: (context, index) {
        final r = _vm.results[index];
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(r.source.name,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          trailing: Text(
            r.error != null ? '失败' : '${r.videos.length}',
            style: TextStyle(
              color: r.error != null ? AppColors.pink : AppColors.accent,
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  void _showSourceSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('选择搜索源', style: TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: _vm.sources
                .map((s) => CheckboxListTile(
                      value: _vm.selectedSourceKeys.contains(s.key),
                      onChanged: (_) => _vm.toggleSource(s.key),
                      title: Text(s.name,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      controlAffinity: ListTileControlAffinity.leading,
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  // 右侧：搜索结果网格（按源分组）
  Widget _buildContent() {
    if (_vm.searching && _vm.results.isEmpty) {
      return LoadingState(
          tip: _vm.mode == SearchMode.fast ? '快速搜索中...' : '搜索中...');
    }
    if (_vm.results.isEmpty) {
      return const EmptyState(tip: '暂无搜索结果', icon: Icons.search_off);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vm.results.length,
      itemBuilder: (context, index) {
        final r = _vm.results[index];
        return _buildSourceSection(r);
      },
    );
  }

  Widget _buildSourceSection(SearchSourceResult r) {
    if (r.videos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text('${r.source.name}：${r.error ?? '无结果'}',
            style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(r.source.name,
                      style: const TextStyle(color: AppColors.accent, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Text('${r.videos.length} 条',
                    style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 150,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.62,
            ),
            itemCount: r.videos.length,
            itemBuilder: (context, index) {
              final v = r.videos[index];
              return VodCard(
                video: v,
                onTap: () => context.push(AppRoutes.detail, extra: {
                  'sourceKey': v.sourceKey.isEmpty ? r.source.key : v.sourceKey,
                  'vodId': v.id,
                  'title': v.name,
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  void _doSearch() {
    final kw = _ctrl.text.trim();
    if (kw.isEmpty) return;
    _vm.search(kw);
  }
}
