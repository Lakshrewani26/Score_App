import 'dart:typed_data';

import '../models/admin_qr_models.dart';
import 'admin_qr_api.dart';
import 'excel_saver/excel_saver.dart';

class AdminQrExcelExporter {
  static const _xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final Future<String?> Function({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) _saver;

  AdminQrExcelExporter({
    Future<String?> Function({
      required Uint8List bytes,
      required String fileName,
      required String mimeType,
    })? saver,
  }) : _saver = saver ?? saveExcelFile;

  Future<String?> exportBatch({
    required AdminQrApi qrApi,
    required AdminQrBatch batch,
  }) async {
    final bytes = await qrApi.downloadBatchExcel(batch.id);
    if (!_hasXlsxSignature(bytes)) {
      throw const FormatException('The server returned an invalid Excel file.');
    }

    return _saver(
      bytes: bytes,
      fileName: '${batch.batchNumber}_qr_codes.xlsx',
      mimeType: _xlsxMimeType,
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
