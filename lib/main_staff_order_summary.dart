import 'package:flutter/material.dart';
import 'features/staff/orders/staff_order_summary_screen.dart';

void main() {
  runApp(const StaffOrderSummaryApp());
}

class StaffOrderSummaryApp extends StatelessWidget {
  const StaffOrderSummaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Order Summary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF083FA5)),
        useMaterial3: true,
      ),
      home: const StaffOrderSummaryScreen(),
    );
  }
}
