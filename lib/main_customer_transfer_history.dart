import 'package:flutter/material.dart';
import 'features/customer/transfer_history/customer_transfer_history_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Transfer History',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CustomerTransferHistoryScreen(),
    ),
  );
}
