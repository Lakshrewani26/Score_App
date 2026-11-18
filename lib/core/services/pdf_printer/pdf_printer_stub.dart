import 'dart:typed_data';

Future<void> printPdfPlatform({
  required Uint8List bytes,
  required String fileName,
}) {
  throw UnsupportedError(
    'PDF printing is not supported on this platform.',
  );
}
