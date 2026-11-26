class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.orderNumber,
    this.partnerName,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final int? orderId;
  final String? orderNumber;
  final String? partnerName;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'new_order',
      title: json['title'] as String? ?? 'New Order Received',
      body: json['body'] as String? ?? '',
      orderId: json['order_id'] as int?,
      orderNumber: json['order_number'] as String?,
      partnerName: json['partner_name'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NotificationsListResult {
  const NotificationsListResult({
    required this.notifications,
    required this.unreadCount,
  });

  final List<AppNotification> notifications;
  final int unreadCount;
}
