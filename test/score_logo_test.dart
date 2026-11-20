import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/widgets/score_logo.dart';

void main() {
  group('ScoreLogo Widget Tests', () {
    testWidgets(
        'renders ScoreLogo.small with expected dimensions and aspect ratio',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScoreLogo.small(),
            ),
          ),
        ),
      );

      final sizedBoxFinder = find.byType(SizedBox);
      expect(sizedBoxFinder, findsWidgets);

      final logoFinder = find.byType(ScoreLogo);
      expect(logoFinder, findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final Image image = tester.widget(imageFinder);
      expect(image.fit, BoxFit.contain);
      expect((image.image as AssetImage).assetName,
          'assets/images/app_logo_blended.png');

      final logoSize = tester.getSize(logoFinder);
      expect(logoSize.height, closeTo(32.0, 0.1));
      expect(logoSize.width, closeTo(32.0 * ScoreLogo.aspectRatio, 0.1));
      expect(logoSize.width / logoSize.height,
          closeTo(ScoreLogo.aspectRatio, 0.01));
    });

    testWidgets(
        'renders ScoreLogo.medium with expected dimensions and aspect ratio',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScoreLogo.medium(),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(ScoreLogo);
      expect(logoFinder, findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final logoSize = tester.getSize(logoFinder);
      expect(logoSize.height, closeTo(56.0, 0.1));
      expect(logoSize.width, closeTo(56.0 * ScoreLogo.aspectRatio, 0.1));
      expect(logoSize.width / logoSize.height,
          closeTo(ScoreLogo.aspectRatio, 0.01));
    });

    testWidgets(
        'renders ScoreLogo.large with expected dimensions and aspect ratio',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScoreLogo.large(),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(ScoreLogo);
      expect(logoFinder, findsOneWidget);

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final logoSize = tester.getSize(logoFinder);
      expect(logoSize.height, closeTo(125.0, 0.1));
      expect(logoSize.width, closeTo(125.0 * ScoreLogo.aspectRatio, 0.1));
      expect(logoSize.width / logoSize.height,
          closeTo(ScoreLogo.aspectRatio, 0.01));
    });

    testWidgets('ScoreLogo.custom computes height automatically from width',
        (tester) async {
      const double customWidth = 140.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScoreLogo.custom(width: customWidth),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(ScoreLogo);
      final logoSize = tester.getSize(logoFinder);

      expect(logoSize.width, closeTo(customWidth, 0.1));
      expect(
          logoSize.height, closeTo(customWidth / ScoreLogo.aspectRatio, 0.1));
      expect(logoSize.width / logoSize.height,
          closeTo(ScoreLogo.aspectRatio, 0.01));
    });

    testWidgets('ScoreLogo.custom computes width automatically from height',
        (tester) async {
      const double customHeight = 60.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ScoreLogo.custom(height: customHeight),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(ScoreLogo);
      final logoSize = tester.getSize(logoFinder);

      expect(logoSize.height, closeTo(customHeight, 0.1));
      expect(
          logoSize.width, closeTo(customHeight * ScoreLogo.aspectRatio, 0.1));
      expect(logoSize.width / logoSize.height,
          closeTo(ScoreLogo.aspectRatio, 0.01));
    });

    testWidgets('handles tight constrained layouts safely without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Center(child: ScoreLogo.medium()),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify no exceptions or overflow occurred
      expect(tester.takeException(), isNull);
      expect(find.byType(ScoreLogo), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('handles unconstrained Row and Column placements without error',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Row(
                  children: [
                    ScoreLogo.small(),
                    ScoreLogo.medium(),
                  ],
                ),
                ScoreLogo.large(),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ScoreLogo), findsNWidgets(3));
      expect(find.byType(Image), findsNWidgets(3));
    });
  });
}
