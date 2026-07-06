import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load any saved backend URL override before the first network call.
  await AppConfig.init();
  runApp(const WeddingApp());
}
