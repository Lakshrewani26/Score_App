import 'package:flutter/material.dart';
import 'features/customer/create_account/create_account_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Create Account',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const CreateAccountScreen(),
    ),
  );
}
