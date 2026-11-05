import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/partner/home/partner_home_screen.dart';
import 'package:score_app/features/partner/profile/partner_profile_screen.dart';
import 'package:score_app/features/partner/transfer/partner_transfer_history_screen.dart';

void main() {
  testWidgets(
      'PartnerTransferHistoryScreen renders an honest empty state',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Title & Subtitle
    expect(find.text('Transfer History'), findsAtLeastNWidgets(1));
    expect(find.text('View your recent transfer transactions'), findsOneWidget);

    expect(
      find.byKey(const Key('partner-transfer-history-empty-state')),
      findsOneWidget,
    );
    expect(find.text('Amit Sharma'), findsNothing);

    // 7. Back Button & Bottom Nav
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigation from PartnerHomeScreen opens PartnerTransferHistoryScreen',
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
    final historyCard = find.text('Points History');
    expect(historyCard, findsOneWidget);

    await tester.ensureVisible(historyCard);
    await tester.tap(historyCard);
    await tester.pumpAndSettle();

    expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);
    expect(find.text('View your recent transfer transactions'), findsOneWidget);
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

    // Navigate to Transfer History
    final historyCard = find.text('Points History');
    await tester.ensureVisible(historyCard);
    await tester.tap(historyCard);
    await tester.pumpAndSettle();

    expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);

    // Test Profile navigation
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerProfileScreen), findsOneWidget);

    // Tapping Home on Profile pops back to PartnerTransferHistoryScreen
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);

    // Test top-left Back button returning to PartnerHomeScreen
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(PartnerHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state renders on mobile viewports',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PartnerTransferHistoryScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PartnerTransferHistoryScreen), findsOneWidget);

    expect(
      find.byKey(const Key('partner-transfer-history-empty-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
