import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

Future<String?> saveExcelPlatform({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  return FlutterFileDialog.saveFile(
    params: SaveFileDialogParams(
      data: bytes,
      fileName: fileName,
      mimeTypesFilter: [mimeType],
    ),
  );
}
