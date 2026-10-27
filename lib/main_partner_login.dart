import 'package:flutter/material.dart';
import 'features/partner/login/partner_login_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Login',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerLoginScreen(),
    ),
  );
}
