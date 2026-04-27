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
}
