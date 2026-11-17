import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('Blob')
extension type JSBlob._(JSObject _) implements JSObject {
  external factory JSBlob(JSArray<JSAny?> blobParts, [JSObject? options]);
}

@JS('HTMLAnchorElement')
extension type JSAnchorElement._(JSObject _) implements JSObject {
  external set href(String value);
  external set download(String value);
  external void click();
}

@JS('URL.createObjectURL')
external String _createObjectURL(JSBlob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('document.createElement')
external JSObject _createElement(String tagName);

Future<String?> saveExcelPlatform({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) async {
  try {
    final options = JSObject();
    options['type'] = mimeType.toJS;
    final jsBytes = bytes.toJS;
    final parts = <JSAny?>[jsBytes].toJS;
    final blob = JSBlob(parts, options);
    final url = _createObjectURL(blob);
    final anchor = _createElement('a') as JSAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();
    Timer(const Duration(seconds: 1), () {
      _revokeObjectURL(url);
    });
    return fileName;
  } catch (e) {
    throw Exception('Failed to trigger file download in browser: $e');
  }
}
