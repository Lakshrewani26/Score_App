import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/features/staff/dealers/staff_dealers_associated_screen.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/orders/staff_orders_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';

class _FakeStaffApi extends StaffApi {
  _FakeStaffApi({
    this.partners = const [],
    this.failFirstRequest = false,
  });

  final List<StaffAssignedPartner> partners;
  final bool failFirstRequest;
  int requests = 0;

  @override
  Future<List<StaffAssignedPartner>> getAssignedPartners() async {
    requests++;
    if (failFirstRequest && requests == 1) {
      throw const StaffApiException('Backend unavailable', statusCode: 503);
    }
    return partners;
  }
}

const _assignedPartner = StaffAssignedPartner(
  id: 21,
  name: 'Nisha Partner',
  mobile: '9000000021',
  businessName: 'Nisha Traders',
  businessAddress: 'Market Road',
  partnerCode: 'PAR-21',
);

void main() {
  group('StaffDealersAssociatedScreen', () {
    testWidgets('shows a genuine empty assignment state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDealersAssociatedScreen(api: _FakeStaffApi()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dealers Associated'), findsOneWidget);
      expect(find.text('Your partner details'), findsOneWidget);
      expect(find.text('Search dealers'), findsOneWidget);
      expect(
        find.text('No Partners have been assigned to your account yet.'),
        findsOneWidget,
      );
      expect(find.text('Rahul Traders'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders only Partners returned by the assignment API',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDealersAssociatedScreen(
            api: _FakeStaffApi(partners: const [_assignedPartner]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nisha Traders'), findsOneWidget);
      expect(find.text('Nisha Partner'), findsOneWidget);
      expect(find.textContaining('Market Road'), findsOneWidget);
      expect(find.text('Add Order'), findsNothing);
    });

    testWidgets('search filters assigned Partner name and business name',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDealersAssociatedScreen(
            api: _FakeStaffApi(partners: const [_assignedPartner]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nisha');
      await tester.pumpAndSettle();
      expect(find.text('Nisha Traders'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No Partners match your search.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows API errors and retries instead of showing an empty list',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeStaffApi(
        partners: const [_assignedPartner],
        failFirstRequest: true,
      );
      await tester.pumpWidget(
        MaterialApp(home: StaffDealersAssociatedScreen(api: api)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backend unavailable'), findsOneWidget);
      expect(
        find.text('No Partners have been assigned to your account yet.'),
        findsNothing,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Nisha Traders'), findsOneWidget);
      expect(api.requests, 2);
    });

    testWidgets('selecting a Dealer opens StaffOrdersScreen with dealer ID and details',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = _FakeStaffApi(partners: const [_assignedPartner]);
      await tester.pumpWidget(
        MaterialApp(
          home: StaffDealersAssociatedScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nisha Traders'), findsOneWidget);
      await tester.tap(find.text('Nisha Traders'));
      await tester.pumpAndSettle();

      expect(find.byType(StaffOrdersScreen), findsOneWidget);
      expect(find.text('Dealer: Nisha Traders (ID: 21)'), findsOneWidget);
      expect(find.text('Select products and quantity'), findsOneWidget);
    });

    testWidgets('Home bottom navigation works', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: StaffHomeScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dealers\nAssociated'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffDealersAssociatedScreen), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Home'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffHomeScreen), findsOneWidget);
    });

    testWidgets('Profile bottom navigation works', (tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: StaffDealersAssociatedScreen(api: _FakeStaffApi()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(InkWell, 'Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffProfileScreen), findsOneWidget);
    });
  });
}
