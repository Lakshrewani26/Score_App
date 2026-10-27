import 'dart:typed_data';

import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import '../models/admin_qr_models.dart';
import 'admin_qr_api.dart';

class AdminQrExcelExporter {
  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  Future<String?> exportBatch({
    required AdminQrApi qrApi,
    required AdminQrBatch batch,
  }) async {
    final bytes = await qrApi.downloadBatchExcel(batch.id);
    if (!_hasXlsxSignature(bytes)) {
      throw const FormatException('The server returned an invalid Excel file.');
    }

    return FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(
        data: bytes,
        fileName: '${batch.batchNumber}_qr_codes.xlsx',
        mimeTypesFilter: const [_xlsxMimeType],
      ),
    );
  }

  bool _hasXlsxSignature(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }
}
