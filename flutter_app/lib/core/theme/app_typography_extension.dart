import 'package:flutter/material.dart';

/// 少数几处复用的语义化文案样式（层级仍对齐 [TextTheme] 槽位）。
@immutable
class AppTypographyTokens extends ThemeExtension<AppTypographyTokens> {
  const AppTypographyTokens({
    required this.composerBody,
    required this.chatBubbleBody,
    required this.chatBubbleLink,
    required this.compactParagraph,
  });

  /// 创作区输入框与同类紧凑输入（较 bodyLarge 略小）。
  final TextStyle composerBody;

  /// 聊天气泡主文。
  final TextStyle chatBubbleBody;

  /// 气泡内次级操作文案（展开/收起等）。
  final TextStyle chatBubbleLink;

  /// 模板详情等略紧凑段落正文。
  final TextStyle compactParagraph;

  static AppTypographyTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppTypographyTokens>() ?? _fallback(theme.textTheme, theme.colorScheme);
  }

  static AppTypographyTokens _fallback(TextTheme textTheme, ColorScheme scheme) {
    final onSurf = scheme.onSurface;
    final muted = scheme.onSurfaceVariant;
    final bl = textTheme.bodyLarge ?? const TextStyle();
    final fs = ((bl.fontSize ?? 16) - 2).clamp(12.0, double.infinity);
    return AppTypographyTokens(
      composerBody: bl.copyWith(fontSize: fs, height: 1.45, color: onSurf),
      chatBubbleBody: (textTheme.bodyMedium ?? const TextStyle())
          .copyWith(color: onSurf, height: 1.45),
      chatBubbleLink: (textTheme.labelSmall ?? const TextStyle())
          .copyWith(color: muted, fontWeight: FontWeight.w600),
      compactParagraph: bl.copyWith(
        fontSize: fs,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: onSurf,
      ),
    );
  }

  @override
  AppTypographyTokens copyWith({
    TextStyle? composerBody,
    TextStyle? chatBubbleBody,
    TextStyle? chatBubbleLink,
    TextStyle? compactParagraph,
  }) {
    return AppTypographyTokens(
      composerBody: composerBody ?? this.composerBody,
      chatBubbleBody: chatBubbleBody ?? this.chatBubbleBody,
      chatBubbleLink: chatBubbleLink ?? this.chatBubbleLink,
      compactParagraph: compactParagraph ?? this.compactParagraph,
    );
  }

  @override
  ThemeExtension<AppTypographyTokens> lerp(
    covariant ThemeExtension<AppTypographyTokens>? other,
    double t,
  ) {
    if (other is! AppTypographyTokens) return this;
    return t < 0.5 ? this : other;
  }
}
