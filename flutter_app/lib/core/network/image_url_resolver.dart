import '../config/app_environment.dart';

class ImageUrlResolver {
  const ImageUrlResolver(this.environment);

  final AppEnvironment environment;

  String resolve(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }

    if (imageUrl.startsWith('http://') ||
        imageUrl.startsWith('https://') ||
        imageUrl.startsWith('data:') ||
        imageUrl.startsWith('blob:')) {
      return imageUrl;
    }

    final base = environment.imageBaseUrl.isNotEmpty
        ? environment.imageBaseUrl
        : environment.apiBaseUrl;

    if (imageUrl.startsWith('/')) {
      return '$base$imageUrl';
    }
    return '$base/$imageUrl';
  }

  /// Prefer CDN zoom thumbnail ([thumbUrl]), then [previewUrl], then original.
  /// Use for all in-app image loading unless a full-size URL is explicitly required.
  String resolveThumbnailLayers({
    String thumbUrl = '',
    String previewUrl = '',
    String imageUrl = '',
  }) {
    final raw = thumbUrl.isNotEmpty
        ? thumbUrl
        : (previewUrl.isNotEmpty ? previewUrl : imageUrl);
    return resolve(raw);
  }
}
