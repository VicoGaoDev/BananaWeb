import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../app/app_providers.dart';

/// 与全局主题一致的深灰背景（近似主色但仍偏中性灰，适于照片衬底）。
const Color _kPreviewBackdrop = Color(0xFF1A1A1A);

class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title = '图片预览',
  });

  final List<String> imageUrls;

  /// 打开时显示的条目下标。
  final int initialIndex;

  /// 保留参数以兼容路由，全屏预览不展示标题。
  final String title;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage> {
  late final List<String> _urls;
  late final PageController _pageController;
  late int _index;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _urls = widget.imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final n = _urls.length;
    _index = n == 0 ? 0 : widget.initialIndex.clamp(0, n - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String get _currentUrl =>
      (_urls.isEmpty || _index < 0 || _index >= _urls.length) ? '' : _urls[_index];

  @override
  Widget build(BuildContext context) {
    final urls = _urls;

    return Scaffold(
      backgroundColor: _kPreviewBackdrop,
      body: urls.isEmpty
          ? Center(
              child: Text(
                '图片地址为空',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                PhotoViewGallery.builder(
                  scrollPhysics: const BouncingScrollPhysics(),
                  pageController: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount: urls.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                  },
                  builder: (context, index) {
                    final url = urls[index];
                    return PhotoViewGalleryPageOptions(
                      imageProvider: CachedNetworkImageProvider(url),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3.2,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Text(
                            '图片加载失败',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                          ),
                        );
                      },
                    );
                  },
                  loadingBuilder: (context, progress) {
                    if (progress == null) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                              : null,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    );
                  },
                  backgroundDecoration: const BoxDecoration(
                    color: _kPreviewBackdrop,
                  ),
                ),
                SafeArea(
                  child: Stack(
                    children: [
                      Positioned(
                        top: 4,
                        left: 12,
                        child: _PreviewChromeButton(
                          tooltip: '返回',
                          onPressed: () => context.pop(),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 12,
                        child: _PreviewChromeButton(
                          tooltip: '保存到相册',
                          onPressed:
                              _currentUrl.isEmpty || _isSaving ? null : _saveImage,
                          child: _isSaving
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                )
                              : Icon(
                                  Icons.download_rounded,
                                  size: 24,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveImage() async {
    final url = _currentUrl.trim();
    if (url.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final hasAccess = await Gal.hasAccess();
      final allowed = hasAccess || await Gal.requestAccess();
      if (!allowed) {
        throw Exception('没有相册访问权限');
      }

      final bytes = await ref.read(dioProvider).get<List<int>>(
            url,
            options: Options(responseType: ResponseType.bytes),
          );

      final data = bytes.data;
      if (data == null || data.isEmpty) {
        throw Exception('图片下载失败');
      }

      await Gal.putImageBytes(
        Uint8List.fromList(data),
        name: 'banana_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片已保存到系统相册')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _PreviewChromeButton extends StatelessWidget {
  const _PreviewChromeButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? const Color(0xFF2F2F2F).withValues(alpha: 0.9)
            : const Color(0xFF2F2F2F).withValues(alpha: 0.45),
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: enabled ? 0.14 : 0.06),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: Colors.white.withValues(alpha: 0.14),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
