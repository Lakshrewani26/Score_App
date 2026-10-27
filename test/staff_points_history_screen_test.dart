import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/points_history/staff_points_history_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';

void main() {
  group('StaffPointsHistoryScreen Tests', () {
    testWidgets(
        'renders StaffPointsHistoryScreen with an honest empty state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPointsHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. "Points History" title is displayed
      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);
      expect(find.text('Points History'), findsOneWidget);

      // 2. "View received points" subtitle is displayed
      expect(find.text('View received points'), findsOneWidget);

      expect(
        find.byKey(const Key('staff-points-history-empty-state')),
        findsOneWidget,
      );
      expect(find.text('Amit Sharma'), findsNothing);

      // 7. Back button is present
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // 8. Home bottom navigation is present
      expect(find.text('Home'), findsOneWidget);

      // 9. Profile bottom navigation is present
      expect(find.text('Profile'), findsOneWidget);

      // 11. Screen does not overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('top-left Back button returns to StaffHomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 12. Existing Staff Home Points History navigation works
      final cardFinder = find.text('Points\nHistory');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back_rounded);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // 10. Tapping Home / Back button returns to Staff Home
      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Home bottom navigation returns to StaffHomeScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.text('Points\nHistory');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPointsHistoryScreen), findsOneWidget);

      // Tap Home tab
      final homeTab = find.text('Home');
      await tester.tap(homeTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Profile bottom navigation navigates to StaffProfileScreen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPointsHistoryScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final profileTab = find.text('Profile');
      await tester.tap(profileTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
