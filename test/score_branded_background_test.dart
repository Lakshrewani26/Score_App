import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:score_app/app/app.dart';
import 'package:score_app/core/widgets/score_branded_background.dart';

void main() {
  testWidgets(
      'Welcome alone gets automotive artwork; routed screens use the standard background',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ScoreApp());

    final welcomePainters = tester
        .widgetList<CustomPaint>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter is ScoreBrandedBackgroundPainter,
          ),
        )
        .map((paint) =>
            (paint.painter! as ScoreBrandedBackgroundPainter).variant);
    expect(
      welcomePainters,
      containsAll([
        ScoreBackgroundVariant.standard,
        ScoreBackgroundVariant.welcome,
      ]),
    );
    expect(find.text('Welcome!'), findsOneWidget);

    for (final role in ['Customer', 'Partner', 'Staff', 'Admin']) {
      await tester.tap(find.text('$role Login').first);
      await tester.pumpAndSettle();

      final routePainters = tester
          .widgetList<CustomPaint>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is ScoreBrandedBackgroundPainter,
            ),
          )
          .map((paint) =>
              (paint.painter! as ScoreBrandedBackgroundPainter).variant);
      expect(routePainters, [ScoreBackgroundVariant.standard]);
      expect(tester.takeException(), isNull);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
    }
  });
}
