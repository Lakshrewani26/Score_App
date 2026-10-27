import 'package:flutter/material.dart';
import 'features/staff/orders/staff_orders_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Add Order',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffOrdersScreen(),
    ),
  );
}
