import 'package:flutter/material.dart';
import 'features/staff/orders/staff_order_status_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Order Status',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffOrderStatusScreen(),
    ),
  );
}
