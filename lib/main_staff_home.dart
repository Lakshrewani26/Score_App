import 'package:flutter/material.dart';
import 'features/staff/home/staff_home_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Staff Home',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffHomeScreen(),
    ),
  );
}
