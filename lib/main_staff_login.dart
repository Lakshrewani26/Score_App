import 'package:flutter/material.dart';
import 'features/staff/login/staff_login_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Staff Login',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffLoginScreen(),
    ),
  );
}
