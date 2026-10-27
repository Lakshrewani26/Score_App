import 'package:flutter/material.dart';
import 'features/partner/transfer/partner_transfer_history_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Transfer History',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerTransferHistoryScreen(),
    ),
  );
}
