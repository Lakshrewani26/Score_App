import 'package:flutter/material.dart';
import 'features/customer/catalogue/two_wheeler_parts_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - 2-Wheeler Parts',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const TwoWheelerPartsScreen(),
    ),
  );
}
