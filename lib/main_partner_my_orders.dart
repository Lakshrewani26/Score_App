import 'package:flutter/material.dart';
import 'features/partner/orders/partner_my_orders_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner My Orders',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerMyOrdersScreen(),
    ),
  );
}
