import 'dart:typed_data';

import 'pdf_printer_stub.dart'
    if (dart.library.io) 'pdf_printer_mobile.dart'
    if (dart.library.js_interop) 'pdf_printer_web.dart';

typedef PdfPrinterFn = Future<void> Function({
  required Uint8List bytes,
  required String fileName,
});

Future<void> printPdfDocument({
  required Uint8List bytes,
  required String fileName,
}) =>
    printPdfPlatform(
      bytes: bytes,
      fileName: fileName,
    );
