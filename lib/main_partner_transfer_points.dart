import 'package:flutter/material.dart';
import 'features/partner/transfer/partner_transfer_points_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Transfer Points',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerTransferPointsScreen(),
    ),
  );
}
