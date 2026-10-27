import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/features/customer/catalogue/catalogue_product_list_screen.dart';
import 'package:score_app/features/customer/catalogue/two_wheeler_parts_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_two_wheeler_catalogue_screen.dart';
import 'package:score_app/features/partner/catalogue/partner_three_wheeler_catalogue_screen.dart';

import 'catalogue_test_support.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  Future<void> tapPage(WidgetTester tester, String key) async {
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('partner pages navigate and stop at both page boundaries', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpScreen(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    expect(find.text('Page 1 of 3 · 45 products'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-previous-page')),
          )
          .onPressed,
      isNull,
    );
    expect(requests.single.queryParameters['page'], '1');

    await tapPage(tester, 'catalogue-next-page');
    expect(find.text('Page 2 of 3 · 45 products'), findsOneWidget);
    expect(requests.last.queryParameters['page'], '2');

    await tapPage(tester, 'catalogue-next-page');
    expect(find.text('Page 3 of 3 · 45 products'), findsOneWidget);
    expect(requests.last.queryParameters['page'], '3');
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('catalogue-next-page')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
      'quantities stay associated with product IDs across pages and filters', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpScreen(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    await tester.tap(find.byKey(const Key('quantity-plus-1')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Selected units: 1'), findsOneWidget);

    await tapPage(tester, 'catalogue-next-page');
    expect(find.text('2-Wheeler Part 21'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Selected units: 1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('quantity-plus-21')));
    await tester.pumpAndSettle();
    expect(find.text('Selected units: 2'), findsOneWidget);

    await tapPage(tester, 'catalogue-previous-page');
    expect(find.text('2-Wheeler Part 1'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Selected units: 2'), findsOneWidget);

    final dropdown = find.byType(DropdownButton<int?>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters').last);
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page'], '1');
    expect(requests.last.queryParameters['category_id'], '2');
    expect(find.text('Selected units: 2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'filter');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['page'], '1');
    expect(requests.last.queryParameters['category_id'], '2');
    expect(requests.last.queryParameters['search'], 'filter');
    expect(find.text('Selected units: 2'), findsOneWidget);
  });

  testWidgets('minus is disabled at zero and selection can be removed', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpScreen(
      tester,
      PartnerThreeWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    final minus = find.byKey(const Key('quantity-minus-1'));
    expect(tester.widget<IconButton>(minus).onPressed, isNull);
    await tester.tap(find.byKey(const Key('quantity-plus-1')));
    await tester.pumpAndSettle();
    await tester.tap(minus);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsNWidgets(2));
    expect(find.text('Selected units: 0'), findsOneWidget);
  });

  testWidgets('vehicle filter updates request and resets to page one', (
    tester,
  ) async {
    final requests = <Uri>[];
    final api = buildTestCatalogueApi(requests);
    await pumpScreen(
      tester,
      CatalogueProductListScreen(
        api: api,
        vehicleType: '2-Wheeler',
        title: '2-Wheeler',
        heroCaption: 'Parts',
        enablePartnerQuantitySelection: true,
      ),
    );

    await tapPage(tester, 'catalogue-next-page');
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogueProductListScreen(
          api: api,
          vehicleType: '3-Wheeler',
          title: '3-Wheeler',
          heroCaption: 'Parts',
          enablePartnerQuantitySelection: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests.last.queryParameters['vehicle_type'], '3-Wheeler');
    expect(requests.last.queryParameters['page'], '1');
    expect(find.text('Page 1 of 3 · 45 products'), findsOneWidget);
  });

  testWidgets(
      'tapping Continue with 0 units validates empty cart, and with selected units opens Order Summary', (
    tester,
  ) async {
    final requests = <Uri>[];
    await pumpScreen(
      tester,
      PartnerTwoWheelerCatalogueScreen(
        api: buildTestCatalogueApi(requests),
      ),
    );

    final continueButton = find.widgetWithText(
      ElevatedButton,
      'Continue',
    );
    expect(continueButton, findsOneWidget);

    // 1. Tapping Continue with empty cart validates and remains on screen
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Please select at least one product with quantity greater than zero.'),
      findsOneWidget,
    );
    expect(find.text('Order Summary'), findsNothing);

    // Dismiss SnackBar so it does not block subsequent taps
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // 2. Select 1 unit
    await tester.tap(find.byKey(const Key('quantity-plus-1')));
    await tester.pumpAndSettle();
    expect(find.text('Selected units: 1'), findsOneWidget);

    // 3. Tapping Continue opens Order Summary
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Order Summary'), findsOneWidget);
    expect(find.text('2-Wheeler Part 1'), findsOneWidget);

    // 4. Returning to catalogue preserves selection
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Selected units: 1'), findsOneWidget);
  });

  testWidgets('customer catalogue remains browse-only with no quantities', (
    tester,
  ) async {
    final requests = <Uri>[];
    final api = buildTestCatalogueApi(requests);
    await pumpScreen(
      tester,
      TwoWheelerPartsScreen(api: api),
    );

    expect(find.byKey(const Key('quantity-plus-1')), findsNothing);
    expect(find.byKey(const Key('quantity-minus-1')), findsNothing);
    expect(find.text('Continue'), findsNothing);
    expect(find.text('2-Wheeler Part 1'), findsOneWidget);
  });
}
