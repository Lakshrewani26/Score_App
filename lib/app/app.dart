import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/widgets/score_branded_background.dart';
import '../features/admin/login/admin_login_screen.dart';
import '../features/welcome/welcome_screen.dart';

class ScoreApp extends StatelessWidget {
  const ScoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Score',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: Colors.transparent,
      ),
      builder: (context, child) => ScoreBrandedBackground(
        variant: ScoreBackgroundVariant.standard,
        child: child,
      ),
      home: kIsWeb ? const AdminLoginScreen() : const WelcomeScreen(),
    );
  }
}
