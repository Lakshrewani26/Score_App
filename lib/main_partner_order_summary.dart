import 'package:flutter/material.dart';

import 'features/partner/orders/partner_order_summary_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Order Summary',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerOrderSummaryScreen(),
    ),
  );
}
