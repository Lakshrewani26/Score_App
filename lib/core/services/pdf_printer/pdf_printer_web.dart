import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('Blob')
extension type JSBlob._(JSObject _) implements JSObject {
  external factory JSBlob(JSArray<JSAny?> blobParts, [JSObject? options]);
}

@JS('URL.createObjectURL')
external String _createObjectURL(JSBlob blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectURL(String url);

@JS('window.open')
external JSObject? _windowOpen(String url, String target);

Future<void> printPdfPlatform({
  required Uint8List bytes,
  required String fileName,
}) async {
  if (bytes.isEmpty) {
    throw Exception('Cannot print empty PDF document.');
  }

  final options = JSObject();
  options['type'] = 'application/pdf'.toJS;
  final jsBytes = bytes.toJS;
  final parts = <JSAny?>[jsBytes].toJS;
  final blob = JSBlob(parts, options);
  final blobUrl = _createObjectURL(blob);

  final document = globalContext['document'] as JSObject?;
  if (document == null) {
    _revokeObjectURL(blobUrl);
    throw Exception('Browser document context is unavailable.');
  }

  final body = document['body'] as JSObject?;
  if (body == null) {
    _revokeObjectURL(blobUrl);
    throw Exception('Browser document body is unavailable.');
  }

  final iframe = document.callMethod('createElement'.toJS, 'iframe'.toJS) as JSObject?;
  if (iframe == null) {
    _revokeObjectURL(blobUrl);
    throw Exception('Failed to create print iframe element.');
  }

  final style = iframe['style'] as JSObject?;
  if (style != null) {
    style['position'] = 'fixed'.toJS;
    style['right'] = '0'.toJS;
    style['bottom'] = '0'.toJS;
    style['width'] = '0'.toJS;
    style['height'] = '0'.toJS;
    style['border'] = '0'.toJS;
    style['visibility'] = 'hidden'.toJS;
  }

  final completer = Completer<void>();
  bool printed = false;

  void cleanup() {
    try {
      body.callMethod('removeChild'.toJS, iframe);
    } catch (_) {}
    try {
      _revokeObjectURL(blobUrl);
    } catch (_) {}
  }

  void fallbackWindowPrint() {
    try {
      final win = _windowOpen(blobUrl, '_blank');
      if (win == null) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Print popup was blocked by browser. Please allow popups for this site to print.'),
          );
        }
        return;
      }
      try {
        win.callMethod('focus'.toJS);
        win.callMethod('print'.toJS);
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete();
      }
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Unable to open print preview in browser: $e'),
        );
      }
    }
  }

  void executePrint() {
    if (printed) return;
    printed = true;

    try {
      final contentWindow = iframe['contentWindow'] as JSObject?;
      if (contentWindow != null) {
        contentWindow.callMethod('focus'.toJS);
        contentWindow.callMethod('print'.toJS);
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else {
        fallbackWindowPrint();
      }
    } catch (_) {
      fallbackWindowPrint();
    } finally {
      // Keep resources alive while the print preview dialog is rendered
      Timer(const Duration(seconds: 60), cleanup);
    }
  }

  // Set onload callback
  iframe['onload'] = (() {
    Timer(const Duration(milliseconds: 300), () {
      executePrint();
    });
  }).toJS;

  iframe['src'] = blobUrl.toJS;
  body.callMethod('appendChild'.toJS, iframe);

  // Fallback timer if browser doesn't dispatch onload for application/pdf in iframe
  Timer(const Duration(milliseconds: 700), () {
    if (!printed) {
      executePrint();
    }
  });

  return completer.future;
}
