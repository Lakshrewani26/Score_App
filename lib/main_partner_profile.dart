import 'package:flutter/material.dart';
import 'features/partner/profile/partner_profile_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Partner Profile',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const PartnerProfileScreen(),
    ),
  );
}
