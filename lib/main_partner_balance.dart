import 'package:flutter/material.dart';
import 'features/partner/balance/partner_balance_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Balance',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerBalanceScreen(),
    ),
  );
}
