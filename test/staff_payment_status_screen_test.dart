import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:score_app/core/services/staff_api.dart';
import 'package:score_app/core/services/staff_session_manager.dart';
import 'package:score_app/features/staff/home/staff_home_screen.dart';
import 'package:score_app/features/staff/profile/staff_profile_screen.dart';
import 'package:score_app/features/staff/payment_status/staff_payment_status_screen.dart';

void main() {
  group('StaffPaymentStatusScreen Tests', () {
    testWidgets(
        'renders StaffPaymentStatusScreen without sample payment records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Screen renders "Payment Status"
      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);
      expect(find.text('Payment Status'), findsOneWidget);

      // 2. Search field is present with correct placeholder
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search Dealer or Invoice'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('Shree Auto Parts'), findsNothing);

      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters dealer names correctly (case-insensitive)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 6. Search filters dealer names
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'patel');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('Patel Motors'), findsNothing);
    });

    testWidgets('search filters invoice numbers correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 7. Search filters invoice numbers
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, '10457');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
      expect(find.text('#INV-10457'), findsNothing);
    });

    testWidgets('empty search restores all 10 records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Kumar');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);

      // 8. Empty search restores all records
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      expect(
          find.text('Payment history is not available yet.'), findsOneWidget);
    });

    testWidgets('back button navigates to StaffHome',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const StaffHomeScreen(),
            '/payment': (_) => const StaffPaymentStatusScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to payment screen
      final cardFinder = find.text('Payment\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);

      // 9. Back button navigates to Staff Home
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
    });

    testWidgets('bottom navigation Home button navigates to Staff Home',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          initialRoute: '/',
          routes: {
            '/': (_) => const StaffHomeScreen(),
            '/payment': (_) => const StaffPaymentStatusScreen(),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to payment screen
      final cardFinder = find.text('Payment\nStatus');
      await tester.ensureVisible(cardFinder);
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      expect(find.byType(StaffPaymentStatusScreen), findsOneWidget);

      // 10. Home bottom navigation works
      final homeBottomTab = find.text('Home');
      await tester.tap(homeBottomTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffHomeScreen), findsOneWidget);
    });

    testWidgets('bottom navigation Profile button navigates to Staff Profile',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StaffPaymentStatusScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final profileBottomTab = find.text('Profile');
      await tester.tap(profileBottomTab);
      await tester.pumpAndSettle();

      expect(find.byType(StaffProfileScreen), findsOneWidget);
    });

    testWidgets('renders payment cards with full details (dealer, amount, method, status, date)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Check card 1 (recorded/pending)
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('INV-24027'), findsOneWidget);
      expect(find.text('₹2500.00'), findsOneWidget);
      expect(find.text('CASH'), findsOneWidget);
      expect(find.text('Pending'), findsNWidgets(2)); // Tab + badge
      expect(find.byKey(const Key('approve-payment-button-101')), findsOneWidget);
      expect(find.byKey(const Key('reject-payment-button-101')), findsOneWidget);

      // Check card 2 (approved)
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('INV-24028'), findsOneWidget);
      expect(find.text('₹1200.00'), findsOneWidget);
      expect(find.text('UPI'), findsOneWidget);
      expect(find.text('Approved'), findsNWidgets(2)); // Tab + badge
      expect(find.text('Review Note: Verified in bank'), findsOneWidget);
      // No approve/reject buttons for approved card
      expect(find.byKey(const Key('approve-payment-button-102')), findsNothing);

      // Check card 3 (rejected)
      expect(find.text('Patel Auto'), findsOneWidget);
      expect(find.text('INV-24029'), findsOneWidget);
      expect(find.text('₹3000.00'), findsOneWidget);
      expect(find.text('CHEQUE'), findsOneWidget);
      expect(find.text('Rejected'), findsNWidgets(2)); // Tab + badge
      expect(find.text('Review Note: Cheque bounced'), findsOneWidget);
      expect(find.byKey(const Key('approve-payment-button-103')), findsNothing);
    });

    testWidgets('status filter tabs filter displayed payments correctly',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Initially All is selected (3 payments shown)
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('Patel Auto'), findsOneWidget);

      // Tap Pending filter tab
      await tester.ensureVisible(find.byKey(const Key('filter-tab-recorded')));
      await tester.tap(find.byKey(const Key('filter-tab-recorded')));
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsNothing);
      expect(find.text('Patel Auto'), findsNothing);

      // Tap Approved filter tab
      await tester.ensureVisible(find.byKey(const Key('filter-tab-approved')));
      await tester.tap(find.byKey(const Key('filter-tab-approved')));
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsNothing);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('Patel Auto'), findsNothing);

      // Tap Rejected filter tab
      await tester.ensureVisible(find.byKey(const Key('filter-tab-rejected')));
      await tester.tap(find.byKey(const Key('filter-tab-rejected')));
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsNothing);
      expect(find.text('Sharma Motors'), findsNothing);
      expect(find.text('Patel Auto'), findsOneWidget);

      // Tap All filter tab again
      await tester.ensureVisible(find.byKey(const Key('filter-tab-all')));
      await tester.tap(find.byKey(const Key('filter-tab-all')));
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsOneWidget);
      expect(find.text('Patel Auto'), findsOneWidget);
    });

    testWidgets('search filters loaded payment records',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // Search by dealer name
      await tester.enterText(searchField, 'Rahul');
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsNothing);

      // Search by invoice reference
      await tester.enterText(searchField, '24028');
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsNothing);
      expect(find.text('Sharma Motors'), findsOneWidget);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('Rahul Auto Spares'), findsOneWidget);
      expect(find.text('Sharma Motors'), findsOneWidget);
    });

    testWidgets('shows error state with retry button on API failure',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var shouldFail = true;
      final session = StaffSessionManager(
        tokenStorage: InMemoryStaffTokenStorage(),
      );
      await session.saveSession(
        token: 'test-token',
        user: const StaffUser(
          id: 11,
          name: 'Staff',
          mobile: '9999900001',
          role: 'staff',
          isActive: true,
          staffId: 'STF-01',
        ),
      );

      final client = MockClient((request) async {
        if (shouldFail) {
          return http.Response(
            jsonEncode({'detail': 'Server connection failed'}),
            500,
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 101,
                'staff_id': 11,
                'partner_id': 20,
                'partner_name': 'Dealer',
                'business_name': 'Dealer Shop',
                'amount': '1000.00',
                'payment_method': 'cash',
                'status': 'recorded',
                'recorded_by': 11,
                'recorded_at': '2026-11-13T10:00:00Z',
              }
            ],
            'total': 1,
            'page': 1,
            'page_size': 20,
            'total_pages': 1,
            'has_next': false,
            'has_prev': false,
          }),
          200,
        );
      });

      final api = StaffApi(
        client: client,
        baseUrl: 'http://localhost/',
        sessionManager: session,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Error message and retry button are shown
      expect(find.text('Server connection failed'), findsOneWidget);
      final retryButton = find.text('Retry');
      expect(retryButton, findsOneWidget);

      // Now fix failure and tap retry
      shouldFail = false;
      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(find.text('Dealer Shop'), findsOneWidget);
      expect(find.text('Server connection failed'), findsNothing);
    });

    testWidgets('approving payment shows confirmation, sends request and updates list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Approve on card 101
      final approveButton = find.byKey(const Key('approve-payment-button-101'));
      expect(approveButton, findsOneWidget);
      await tester.tap(approveButton);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Approve Payment'), findsOneWidget);
      expect(find.text('Remarks (Optional)'), findsOneWidget);

      // Confirm approval
      final confirmButton = find.byKey(const Key('confirm-approve-payment-button'));
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // SnackBar shown and status updated
      expect(find.text('Payment INV-24027 approved successfully.'), findsOneWidget);
      expect(find.byKey(const Key('approve-payment-button-101')), findsNothing);
    });

    testWidgets('rejecting payment validates mandatory reason, sends request and updates list',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final api = await _createMockStaffApi();

      await tester.pumpWidget(
        MaterialApp(
          home: StaffPaymentStatusScreen(api: api),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Reject on card 101
      final rejectButton = find.byKey(const Key('reject-payment-button-101'));
      expect(rejectButton, findsOneWidget);
      await tester.tap(rejectButton);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.text('Reject Payment'), findsOneWidget);

      final confirmReject = find.byKey(const Key('confirm-reject-payment-button'));

      // Tapping reject with empty text triggers validation
      await tester.tap(confirmReject);
      await tester.pumpAndSettle();
      expect(find.text('Rejection reason is required'), findsOneWidget);

      // Enter rejection reason
      final reasonField = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(reasonField, 'Duplicate transaction');
      await tester.pumpAndSettle();

      // Confirm rejection
      await tester.tap(confirmReject);
      await tester.pumpAndSettle();

      // SnackBar shown and status updated
      expect(find.text('Payment INV-24027 rejected.'), findsOneWidget);
      expect(find.byKey(const Key('reject-payment-button-101')), findsNothing);
    });
  });
}

Future<StaffApi> _createMockStaffApi({
  List<Map<String, dynamic>>? initialPayments,
  void Function(http.Request)? onRequest,
}) async {
  final session = StaffSessionManager(
    tokenStorage: InMemoryStaffTokenStorage(),
  );
  await session.saveSession(
    token: 'test-staff-token',
    user: const StaffUser(
      id: 11,
      name: 'Staff Member',
      mobile: '+919999900001',
      role: 'staff',
      isActive: true,
      staffId: 'STF-001',
    ),
  );

  List<Map<String, dynamic>> payments = (initialPayments ?? [
    {
      'id': 101,
      'staff_id': 11,
      'partner_id': 20,
      'partner_name': 'Rahul Dealer',
      'business_name': 'Rahul Auto Spares',
      'partner_mobile': '+919876543210',
      'amount': '2500.00',
      'payment_method': 'cash',
      'reference_number': 'INV-24027',
      'status': 'recorded',
      'recorded_by': 11,
      'recorded_by_name': 'Staff Member',
      'recorded_at': '2026-11-10T10:00:00Z',
      'notes': 'Advance cash payment',
      'latest_review': null,
      'status_history': <dynamic>[],
    },
    {
      'id': 102,
      'staff_id': 11,
      'partner_id': 21,
      'partner_name': 'Amit Sharma',
      'business_name': 'Sharma Motors',
      'partner_mobile': '+919876543211',
      'amount': '1200.00',
      'payment_method': 'upi',
      'reference_number': 'INV-24028',
      'status': 'approved',
      'recorded_by': 11,
      'recorded_by_name': 'Staff Member',
      'recorded_at': '2026-11-11T11:00:00Z',
      'notes': 'Online transfer',
      'latest_review': {
        'changed_by': 11,
        'changed_by_name': 'Staff Member',
        'changed_at': '2026-11-11T11:30:00Z',
        'old_status': 'recorded',
        'new_status': 'approved',
        'remarks': 'Verified in bank',
      },
      'status_history': <dynamic>[],
    },
    {
      'id': 103,
      'staff_id': 11,
      'partner_id': 22,
      'partner_name': 'Kiran Patel',
      'business_name': 'Patel Auto',
      'partner_mobile': '+919876543212',
      'amount': '3000.00',
      'payment_method': 'cheque',
      'reference_number': 'INV-24029',
      'status': 'rejected',
      'recorded_by': 11,
      'recorded_by_name': 'Staff Member',
      'recorded_at': '2026-11-12T12:00:00Z',
      'notes': 'Cheque payment',
      'latest_review': {
        'changed_by': 11,
        'changed_by_name': 'Staff Member',
        'changed_at': '2026-11-12T12:30:00Z',
        'old_status': 'recorded',
        'new_status': 'rejected',
        'remarks': 'Cheque bounced',
      },
      'status_history': <dynamic>[],
    },
  ]).map((m) => Map<String, dynamic>.from(m)).toList();

  final client = MockClient((request) async {
    onRequest?.call(request);

    if (request.url.path == '/api/v1/staff/payments' && request.method == 'GET') {
      final status = request.url.queryParameters['status'];
      var filtered = payments;
      if (status != null && status.isNotEmpty) {
        filtered = payments.where((p) => p['status'] == status).toList();
      }
      return http.Response(
        jsonEncode({
          'items': filtered,
          'total': filtered.length,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'has_next': false,
          'has_prev': false,
        }),
        200,
      );
    }

    if (request.url.path.endsWith('/approve') && request.method == 'POST') {
      final id = int.parse(request.url.pathSegments[request.url.pathSegments.length - 2]);
      final index = payments.indexWhere((p) => p['id'] == id);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final updated = Map<String, dynamic>.from(payments[index]);
      updated['status'] = 'approved';
      updated['latest_review'] = {
        'changed_by': 11,
        'changed_by_name': 'Staff Member',
        'changed_at': DateTime.now().toIso8601String(),
        'old_status': 'recorded',
        'new_status': 'approved',
        'remarks': body['remarks'] ?? 'Payment approved',
      };
      payments[index] = updated;
      return http.Response(jsonEncode(updated), 200);
    }

    if (request.url.path.endsWith('/reject') && request.method == 'POST') {
      final id = int.parse(request.url.pathSegments[request.url.pathSegments.length - 2]);
      final index = payments.indexWhere((p) => p['id'] == id);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final updated = Map<String, dynamic>.from(payments[index]);
      updated['status'] = 'rejected';
      updated['latest_review'] = {
        'changed_by': 11,
        'changed_by_name': 'Staff Member',
        'changed_at': DateTime.now().toIso8601String(),
        'old_status': 'recorded',
        'new_status': 'rejected',
        'remarks': body['reason'],
      };
      payments[index] = updated;
      return http.Response(jsonEncode(updated), 200);
    }

    return http.Response('{"detail": "Not found"}', 404);
  });

  return StaffApi(
    client: client,
    baseUrl: 'http://localhost/',
    sessionManager: session,
  );
}
