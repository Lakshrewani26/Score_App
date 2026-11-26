import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  NotificationService.instance.attachBinding();
  runApp(const ScoreApp());
}
