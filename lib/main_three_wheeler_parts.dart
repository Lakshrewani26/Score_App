import 'package:flutter/material.dart';
import 'features/customer/catalogue/three_wheeler_parts_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - 3-Wheeler Parts',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const ThreeWheelerPartsScreen(),
    ),
  );
}
