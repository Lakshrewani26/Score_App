import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:score_app/core/models/notification_models.dart';
import 'package:score_app/core/widgets/order_notification_dialog.dart';

AppNotification _makeNotification({
  int id = 1,
  String title = 'New Order Received',
  String body = 'Order summary here',
  int? orderId = 42,
  String? orderNumber = 'ORD-00042',
  String? partnerName = 'ABC Motors',
}) =>
    AppNotification(
      id: id,
      type: 'new_order',
      title: title,
      body: body,
      orderId: orderId,
      orderNumber: orderNumber,
      partnerName: partnerName,
      isRead: false,
      createdAt: DateTime(2026, 11, 24),
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  group('OrderNotificationDialog', () {
    testWidgets('shows bell icon', (WidgetTester tester) async {
      final notification = _makeNotification();
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.byIcon(Icons.notifications_active_rounded), findsOneWidget);
    });

    testWidgets('shows notification title', (WidgetTester tester) async {
      final notification = _makeNotification(title: 'New Order Received');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('New Order Received'), findsWidgets);
    });

    testWidgets('shows order number from orderNumber field',
        (WidgetTester tester) async {
      final notification = _makeNotification(orderNumber: 'ORD-00042');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('ORD-00042'), findsOneWidget);
    });

    testWidgets('falls back to ORD-{orderId} when orderNumber is null',
        (WidgetTester tester) async {
      final notification = _makeNotification(orderId: 99, orderNumber: null);
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('ORD-99'), findsOneWidget);
    });

    testWidgets('shows partner name', (WidgetTester tester) async {
      final notification = _makeNotification(partnerName: 'ABC Motors');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('ABC Motors'), findsOneWidget);
    });

    testWidgets('shows "Partner" fallback when partnerName is null',
        (WidgetTester tester) async {
      final notification = _makeNotification(partnerName: null);
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('Partner'), findsOneWidget);
    });

    testWidgets('shows order body/summary when non-empty',
        (WidgetTester tester) async {
      final notification = _makeNotification(body: 'Order summary here');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('Order summary here'), findsOneWidget);
    });

    testWidgets('View Order button triggers onViewOrder callback',
        (WidgetTester tester) async {
      var viewOrderCalled = false;
      final notification = _makeNotification();
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () => viewOrderCalled = true,
        onDismiss: () {},
      )));
      await tester.tap(find.byKey(const Key('notification_view_order_button')));
      expect(viewOrderCalled, isTrue);
    });

    testWidgets('Dismiss button triggers onDismiss callback',
        (WidgetTester tester) async {
      var dismissCalled = false;
      final notification = _makeNotification();
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () => dismissCalled = true,
      )));
      await tester.tap(find.byKey(const Key('notification_dismiss_button')));
      expect(dismissCalled, isTrue);
    });

    testWidgets('uses "New Order Received" fallback title when title is empty',
        (WidgetTester tester) async {
      final notification = _makeNotification(title: '');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('New Order Received'), findsWidgets);
    });

    testWidgets('does not show summary text when body is empty',
        (WidgetTester tester) async {
      final notification = _makeNotification(body: '');
      await tester.pumpWidget(_wrap(OrderNotificationDialog(
        notification: notification,
        onViewOrder: () {},
        onDismiss: () {},
      )));
      expect(find.text('Order summary here'), findsNothing);
    });
  });
}
