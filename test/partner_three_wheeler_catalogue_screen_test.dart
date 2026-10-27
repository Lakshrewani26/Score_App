import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/partner/catalogue/partner_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_three_wheeler_catalogue_screen.dart';

import 'catalogue_test_support.dart';

void main() {
  Future<void> pumpCatalogue(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
  }

  testWidgets('loads API products with the 3-Wheeler filter', (tester) async {
    final requests = <Uri>[];
    await pumpCatalogue(
      tester,
      PartnerThreeWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    expect(find.byType(PartnerThreeWheelerCatalogueScreen), findsOneWidget);
    expect(find.text('3-Wheeler Part 1'), findsOneWidget);
    expect(find.text('Search for parts...'), findsOneWidget);
    expect(requests.single.queryParameters['vehicle_type'], '3-Wheeler');
    expect(requests.single.queryParameters['page'], '1');
    expect(requests.single.queryParameters['page_size'], '20');
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Continue'), findsOneWidget);
    final nextPage = find.byKey(const Key('catalogue-next-page'));
    await tester.ensureVisible(nextPage);
    await tester.tap(nextPage);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page'], '2');
    expect(requests.last.queryParameters['vehicle_type'], '3-Wheeler');
    expect(find.text('Page 2 of 3 · 45 products'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('back navigation returns to partner catalogue selector', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpCatalogue(
      tester,
      PartnerThreeWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(PartnerProductCatalogueScreen), findsOneWidget);
  });
}
