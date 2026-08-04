// 影片卡片，对应原项目 item_grid.xml + GridAdapter
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/models/movie.dart';

class VodCard extends StatelessWidget {
  const VodCard({
    super.key,
    required this.video,
    this.onTap,
    this.focusNode,
    this.autofocus = false,
  });

  final MovieVideo video;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      child: Builder(builder: (context) {
        final focused = Focus.of(context).hasFocus;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: focused ? Matrix4.diagonal3Values(1.05, 1.05, 1.0) : Matrix4.identity(),
            transformAlignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: focused ? AppColors.focusBorder : Colors.transparent,
                  width: focused ? 2 : 0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        video.pic.isEmpty
                            ? Container(
                                color: AppColors.panelLight,
                                child: const Icon(Icons.movie_outlined,
                                    color: AppColors.textHint, size: 32),
                              )
                            : CachedNetworkImage(
                                imageUrl: video.pic,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(color: AppColors.panelLight),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.panelLight,
                                  child: const Icon(Icons.broken_image_outlined,
                                      color: AppColors.textHint, size: 28),
                                ),
                              ),
                        if (video.note.isNotEmpty)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xAA000000),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                video.note,
                                style: const TextStyle(color: Colors.white, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
                    child: Text(
                      video.name.isEmpty ? '未知' : video.name,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
