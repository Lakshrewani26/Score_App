import 'package:flutter/material.dart';
import 'features/staff/dealers/staff_dealers_associated_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Dealers Associated',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffDealersAssociatedScreen(),
    ),
  );
}
