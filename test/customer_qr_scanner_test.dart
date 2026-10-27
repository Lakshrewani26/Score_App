import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:score_app/features/customer/home/customer_home_screen.dart';
import 'package:score_app/features/customer/qr_scanner/customer_qr_scanner.dart';

void main() {
  testWidgets('CustomerQrScannerSheet in Scan mode displays required UI elements AND Enter Code Manually', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => CustomerQrScannerSheet.show(context, mode: ScannerMode.scan),
              child: const Text('Open Scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Scanner'));
    await tester.pumpAndSettle();

    // 1. Header and Close Button
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 2. Scanner Area and Instructions
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.text('Position the QR code inside the frame'), findsOneWidget);

    // 3. Enter Code Manually Button IS present in Scan mode
    expect(find.text('Enter Code Manually'), findsOneWidget);

    // 4. Verify no layout exceptions
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping Enter Code Manually in Scan mode opens manual code entry dialog', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => CustomerQrScannerSheet.show(context, mode: ScannerMode.scan),
              child: const Text('Open Scanner'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Scanner'));
    await tester.pumpAndSettle();

    expect(find.text('Enter Code Manually'), findsOneWidget);
    await tester.tap(find.text('Enter Code Manually'));
    await tester.pumpAndSettle();

    // Verify dialog opens
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.widgetWithText(AlertDialog, 'Enter Code Manually'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enter product code'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);

    // Test entering a code and submitting
    await tester.enterText(find.byType(TextField), 'PARTNER123');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    // Verify QR Code Detected dialog shows entered code
    expect(find.text('QR Code Detected'), findsOneWidget);
    expect(find.text('PARTNER123'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets("Tapping Scan Partner's QR Code on CustomerHome opens popup modal with Enter Code Manually", (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify home screen is loaded and displays "Scan Partner's QR Code"
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(CustomerQrScannerSheet), findsNothing);
    final scanCard = find.text("Scan Partner's QR Code");
    expect(scanCard, findsOneWidget);

    // Ensure card is visible and tap it
    await tester.ensureVisible(scanCard);
    await tester.pumpAndSettle();
    await tester.tap(scanCard);
    await tester.pumpAndSettle();

    // Verify modal popup opened over CustomerHomeScreen
    expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
    expect(find.text('Position the QR code inside the frame'), findsOneWidget);
    expect(find.text('Enter Code Manually'), findsOneWidget);

    // Tap close button (X)
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify popup is dismissed and Home screen remains visible
    expect(find.byType(CustomerQrScannerSheet), findsNothing);
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CustomerQrScannerSheet renders without overflow on smaller mobile viewports', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final scanCard = find.text("Scan Partner's QR Code");
    await tester.ensureVisible(scanCard);
    await tester.pumpAndSettle();
    await tester.tap(scanCard);
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(find.text('Enter Code Manually'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping Transfer Points on CustomerHome opens scanner in TransferPoints mode WITHOUT Enter Code Manually', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: CustomerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(find.byType(CustomerQrScannerSheet), findsNothing);
    final transferPointsCard = find.text('Transfer Points');
    expect(transferPointsCard, findsOneWidget);

    // Tap "Transfer Points"
    await tester.ensureVisible(transferPointsCard);
    await tester.pumpAndSettle();
    await tester.tap(transferPointsCard);
    await tester.pumpAndSettle();

    // Verify modal popup opened over CustomerHomeScreen
    expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CustomerQrScannerSheet),
        matching: find.text('Scan QR Code'),
      ),
      findsOneWidget,
    );
    expect(find.text('Position the QR code inside the frame'), findsOneWidget);

    // In Transfer Points mode, Enter Code Manually MUST NOT be visible
    expect(find.text('Enter Code Manually'), findsNothing);

    // Tap close button (X)
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // Verify popup is dismissed and Home screen remains visible
    expect(find.byType(CustomerQrScannerSheet), findsNothing);
    expect(find.byType(CustomerHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
