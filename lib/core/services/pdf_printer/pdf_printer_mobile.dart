import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

Future<void> printPdfPlatform({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (bytes.isEmpty) {
    throw Exception('Cannot print empty PDF document.');
  }

  final savedPath = await FlutterFileDialog.saveFile(
    params: SaveFileDialogParams(
      data: bytes,
      fileName: fileName,
      mimeTypesFilter: ['application/pdf'],
    ),
  );

  if (savedPath == null) {
    throw Exception('PDF save/print cancelled.');
  }
}
