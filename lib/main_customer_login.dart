import 'package:flutter/material.dart';
import 'features/customer/login/customer_login_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Customer Login',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CustomerLoginScreen(),
    ),
  );
}
