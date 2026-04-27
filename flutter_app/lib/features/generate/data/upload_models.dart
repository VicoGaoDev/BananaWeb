class UploadedReferenceImage {
  const UploadedReferenceImage({
    required this.localPath,
    required this.remoteUrl,
    required this.fileName,
  });

  final String localPath;
  final String remoteUrl;
  final String fileName;
}
