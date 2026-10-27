import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:score_app/features/customer/qr_scanner/customer_qr_scanner.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_points_screen.dart';

void main() {
  testWidgets('PartnerTransferPointsScreen renders with all required UI elements',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerTransferPointsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Title & Subtitle
    expect(find.text('Transfer Points'), findsAtLeastNWidgets(1));
    expect(find.text('Transfer points to staff securely'), findsOneWidget);

    // 2. Verify Available Balance
    expect(find.text('Available Points'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    // 3. Verify Selection Options
    expect(find.text('Scan Staff QR Code'), findsOneWidget);
    expect(find.text('Enter Staff ID'), findsOneWidget);

    // 4. Verify Points Input & Transfer Button
    expect(find.text('Points to Transfer'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Transfer Points'), findsOneWidget);

    // 5. Verify Back Button & Bottom Navigation
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigation from PartnerHomeScreen opens PartnerTransferPointsScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PartnerHomeScreen), findsOneWidget);
    final transferCard = find.text('Transfer Points');
    expect(transferCard, findsOneWidget);

    await tester.ensureVisible(transferCard);
    await tester.tap(transferCard);
    await tester.pumpAndSettle();

    expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);
    expect(find.text('Transfer points to staff securely'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual Staff ID input and points validation work properly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerTransferPointsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Enter Staff ID" button to expand manual entry
    final enterStaffIdBtn = find.text('Enter Staff ID');
    expect(enterStaffIdBtn, findsOneWidget);
    await tester.tap(enterStaffIdBtn);
    await tester.pumpAndSettle();

    // Verify text field appears
    final staffIdField = find.widgetWithText(TextField, 'Enter Staff ID');
    expect(staffIdField, findsOneWidget);

    // Enter Staff ID and tap Continue
    await tester.enterText(staffIdField, 'STAFF-999');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();

    // Verify selected staff section displays entered Staff ID
    expect(find.text('STAFF-999'), findsOneWidget);

    // Initially points are empty, transfer button should be disabled
    final transferBtn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Transfer Points'),
    );
    expect(transferBtn.onPressed, isNull);

    // Enter invalid points (e.g. 0)
    final pointsField = find.widgetWithText(TextField, 'Enter points');
    await tester.enterText(pointsField, '0');
    await tester.pumpAndSettle();

    // Transfer button remains disabled for 0 points
    final transferBtn0 = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Transfer Points'),
    );
    expect(transferBtn0.onPressed, isNull);

    // Enter valid points (e.g. 500)
    await tester.enterText(pointsField, '500');
    await tester.pumpAndSettle();

    // Transfer button should now be enabled
    final transferBtnValid = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Transfer Points'),
    );
    expect(transferBtnValid.onPressed, isNotNull);

    // Tap Transfer Points button
    final transferButtonFinder = find.widgetWithText(ElevatedButton, 'Transfer Points');
    await tester.ensureVisible(transferButtonFinder);
    await tester.tap(transferButtonFinder);
    await tester.pumpAndSettle();

    // The UI makes no success claim without a backend transfer endpoint.
    expect(find.text('Points transfer is not available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('QR Scanner option opens CustomerQrScannerSheet (real scanner reuse)',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerTransferPointsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap "Scan Staff QR Code"
    final scanBtn = find.text('Scan Staff QR Code');
    expect(scanBtn, findsOneWidget);
    await tester.tap(scanBtn);
    await tester.pumpAndSettle();

    // Verify CustomerQrScannerSheet opens with real MobileScanner
    expect(find.byType(CustomerQrScannerSheet), findsOneWidget);
    expect(find.byType(MobileScanner), findsOneWidget);
    expect(find.text('Position the QR code inside the frame'), findsOneWidget);

    // Close scanner
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(CustomerQrScannerSheet), findsNothing);
    expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back button returns to PartnerHomeScreen and Profile nav works',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Transfer Points
    final transferCard = find.text('Transfer Points');
    await tester.ensureVisible(transferCard);
    await tester.tap(transferCard);
    await tester.pumpAndSettle();

    expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);

    // Test Profile navigation
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerProfileScreen), findsOneWidget);

    // Tapping Home on Profile pops back to PartnerTransferPointsScreen
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerTransferPointsScreen), findsOneWidget);

    // Test top-left Back button returning to PartnerHomeScreen
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(PartnerHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
