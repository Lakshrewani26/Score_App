import 'package:flutter/material.dart';
import 'features/staff/points_history/staff_points_history_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score - Points History',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const StaffPointsHistoryScreen(),
    ),
  );
}
