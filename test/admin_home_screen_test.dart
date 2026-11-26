import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:score_app/core/models/admin_models.dart';
import 'package:score_app/core/widgets/score_logo.dart';
import 'package:score_app/features/admin/home/admin_home_screen.dart';

void main() {
  final testUser = AdminUser(
    id: 1,
    name: 'Test Admin',
    mobile: '9000000000',
    role: 'admin',
    isActive: true,
  );

  testWidgets('Admin home header uses ScoreLogo.large', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminHomeScreen(adminUser: testUser),
      ),
    );

    // Verify ScoreLogo.large() is present in the header
    final logoFinder = find.byWidgetPredicate(
      (widget) =>
          widget is ScoreLogo && widget.size == ScoreLogoSize.large,
    );
    expect(logoFinder, findsOneWidget);
  });

  testWidgets('Admin home header SizedBox has height 130', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminHomeScreen(adminUser: testUser),
      ),
    );

    // Find SizedBox widgets with height 130 (the header container)
    final headerBox = find.byWidgetPredicate(
      (widget) =>
          widget is SizedBox &&
          widget.height == 130.0 &&
          widget.width == double.infinity,
    );
    expect(headerBox, findsOneWidget);
  });

  testWidgets('Admin home header does not use ScoreLogo.medium', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminHomeScreen(adminUser: testUser),
      ),
    );

    // ScoreLogo.medium should NOT appear in the header stack area
    // (the header SizedBox has height 130 and contains ScoreLogo.large)
    final mediumLogos = find.byWidgetPredicate(
      (widget) =>
          widget is ScoreLogo && widget.size == ScoreLogoSize.medium,
    );
    // No medium logo should be rendered on the admin home screen
    expect(mediumLogos, findsNothing);
  });
}
