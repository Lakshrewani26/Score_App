import 'package:flutter/material.dart';

import 'features/partner/orders/partner_three_wheeler_order_summary_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner 3-Wheeler Order Summary',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerThreeWheelerOrderSummaryScreen(),
    ),
  );
}
