import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:photo_view/photo_view.dart';

import '../../../app/app_providers.dart';

class ImagePreviewPage extends ConsumerStatefulWidget {
  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    this.title = '图片预览',
  });

  final String imageUrl;
  final String title;

  @override
  ConsumerState<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends ConsumerState<ImagePreviewPage> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.imageUrl;
    final title = widget.title;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: imageUrl.isEmpty || _isSaving ? null : _saveImage,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_outlined),
            tooltip: '保存到相册',
          ),
        ],
      ),
      body: imageUrl.isEmpty
          ? const Center(child: Text('图片地址为空'))
          : PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              backgroundDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              loadingBuilder: (context, _) {
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('图片加载失败'));
              },
            ),
    );
  }

  Future<void> _saveImage() async {
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
            widget.imageUrl,
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
