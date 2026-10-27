import 'package:flutter/material.dart';
import 'features/customer/profile/customer_profile_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Customer Profile',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CustomerProfileScreen(),
    ),
  );
}
