import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_providers.dart';
import '../../../core/theme/app_typography_extension.dart';
import '../../../shared/widgets/smooth_async_switcher.dart';
import '../../generate/presentation/generate_draft_controller.dart';
import '../../home/presentation/home_shell_controller.dart';
import '../data/template_models.dart';
import '../data/template_repository.dart';

/// 提示词区域：高度为 1～3 行（按实际换行）；超过三行时用三行可视高度并可滚动。
({double height, bool scrollable}) _measurePromptArea(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth,
) {
  if (!(maxWidth > 0 && maxWidth.isFinite)) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final oneLine =
        ((style.fontSize ?? 14) * (style.height ?? 1.45) * scale).clamp(8.0, double.infinity);
    return (height: oneLine, scrollable: false);
  }

  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: maxWidth);

  final metrics = painter.computeLineMetrics();
  final lineCount = math.max(1, metrics.length);

  if (lineCount <= 3) {
    return (height: painter.height, scrollable: false);
  }

  var sum = 0.0;
  for (var i = 0; i < math.min(3, metrics.length); i++) {
    sum += metrics[i].height;
  }
  return (height: sum, scrollable: true);
}

class TemplateDetailPage extends ConsumerWidget {
  const TemplateDetailPage({
    super.key,
    required this.templateId,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = int.tryParse(templateId);
    final imageResolver = ref.watch(imageUrlResolverProvider);

    if (parsedId == null) {
      return _FullscreenShell(
        onBack: () => context.pop(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '无效的模板 ID：$templateId',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final detailAsync = ref.watch(templateDetailProvider(parsedId));

    return SmoothAsyncSwitcher<CreativeTemplate>(
      asyncValue: detailAsync,
      loading: () => _FullscreenShell(
        onBack: () => context.pop(),
        child: const Center(child: CircularProgressIndicator(color: Colors.white70)),
      ),
      error: (error, _) => _FullscreenShell(
        onBack: () => context.pop(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '模板加载失败：$error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      data: (template) {
        final fullUrl = imageResolver.resolveFullImageLayers(
          imageUrl: template.resultImage,
          thumbUrl: template.resultImageThumb,
        );
        final promptText = template.prompt.isEmpty ? '未命名模板' : template.prompt;
        final baseStyle = AppTypographyTokens.of(context).compactParagraph.copyWith(
          color: Colors.white.withValues(alpha: 0.96),
          shadows: const [
            Shadow(
              blurRadius: 12,
              offset: Offset(0, 2),
              color: Color(0x99000000),
            ),
          ],
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: fullUrl.isEmpty
                    ? const ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              color: Colors.white38, size: 40),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: fullUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        placeholder: (context, url) => const ColoredBox(
                          color: Colors.black,
                          child: Center(child: CircularProgressIndicator(color: Colors.white38)),
                        ),
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: Colors.black,
                          child: Center(
                            child:
                                Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
                          ),
                        ),
                      ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: IconButton(
                      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final w = constraints.maxWidth;
                            final m = _measurePromptArea(context, promptText, baseStyle, w);

                            return ClipRect(
                              child: SizedBox(
                                height: m.height,
                                child: SingleChildScrollView(
                                  physics: m.scrollable
                                      ? const BouncingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  child: Text(promptText, style: baseStyle),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Align(
                          child: ConstrainedBox(
                            constraints:
                                const BoxConstraints(minWidth: 200, maxWidth: 360),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(999),
                              clipBehavior: Clip.antiAlias,
                              elevation: 4,
                              shadowColor: Colors.black54,
                              child: InkWell(
                                onTap: () {
                                  ref
                                      .read(generateDraftControllerProvider.notifier)
                                      .applyTemplate(template);
                                  ref.read(homeTabIndexProvider.notifier).state = 1;
                                  context.go('/');
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 32),
                                  child: Text(
                                    '使用模版',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FullscreenShell extends StatelessWidget {
  const _FullscreenShell({
    required this.onBack,
    required this.child,
  });

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          child,
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black.withValues(alpha: 0.85),
                      ),
                    ],
                  ),
                  onPressed: onBack,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
