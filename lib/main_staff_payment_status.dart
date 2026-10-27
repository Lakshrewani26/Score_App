import 'package:flutter/material.dart';
import 'features/staff/payment_status/staff_payment_status_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Payment Status',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffPaymentStatusScreen(),
    ),
  );
}
