import 'dart:typed_data';

import 'excel_saver_stub.dart'
    if (dart.library.io) 'excel_saver_mobile.dart'
    if (dart.library.js_interop) 'excel_saver_web.dart';

Future<String?> saveExcelFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) =>
    saveExcelPlatform(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
    );
