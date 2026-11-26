import 'package:flutter/material.dart';

import '../models/notification_models.dart';

class OrderNotificationDialog extends StatelessWidget {
  const OrderNotificationDialog({
    super.key,
    required this.notification,
    required this.onViewOrder,
    required this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback onViewOrder;
  final VoidCallback onDismiss;

  static const _royalBlue = Color(0xFF083FA5);
  static const _deepBlue = Color(0xFF072763);

  @override
  Widget build(BuildContext context) {
    final orderLabel = notification.orderNumber ??
        (notification.orderId != null ? 'ORD-${notification.orderId}' : 'New Order');
    final partnerLabel = notification.partnerName ?? 'Partner';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: _royalBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title.isNotEmpty
                            ? notification.title
                            : 'New Order Received',
                        style: const TextStyle(
                          color: _deepBlue,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'A new order has been placed',
                        style: TextStyle(
                          color: Color(0xFF557A95),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBEBFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Order: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF557A95),
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          orderLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _deepBlue,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text(
                        'Partner: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF557A95),
                          fontSize: 13,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          partnerLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _royalBlue,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFE3F2FD)),
                    const SizedBox(height: 8),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF455A64),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('notification_dismiss_button'),
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF546E7A),
                      side: const BorderSide(color: Color(0xFFCFD8DC)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    key: const Key('notification_view_order_button'),
                    onPressed: onViewOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _royalBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'View Order',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
