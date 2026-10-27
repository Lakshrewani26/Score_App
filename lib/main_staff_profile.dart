import 'package:flutter/material.dart';
import 'features/staff/profile/staff_profile_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Staff Profile',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffProfileScreen(),
    ),
  );
}
