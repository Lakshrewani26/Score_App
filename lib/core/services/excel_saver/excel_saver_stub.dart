import 'dart:typed_data';

Future<String?> saveExcelPlatform({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError(
    'Excel file saving is not supported on this platform.',
  );
}
