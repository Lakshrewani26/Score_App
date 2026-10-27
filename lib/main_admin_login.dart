import 'package:flutter/material.dart';
import 'features/admin/login/admin_login_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Admin Login',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const AdminLoginScreen(),
    ),
  );
}
