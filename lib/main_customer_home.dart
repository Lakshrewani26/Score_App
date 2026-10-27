import 'package:flutter/material.dart';
import 'features/customer/home/customer_home_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Customer Home',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CustomerHomeScreen(),
    ),
  );
}
