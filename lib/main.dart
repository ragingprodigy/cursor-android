import 'dart:developer' as developer;

import 'package:cursor/app/app.dart';
import 'package:cursor/app/di.dart';
import 'package:cursor/core/config/app_config.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final dependencies = await AppDependencies.create(config);
  try {
    await dependencies.authSession.restore();
  } catch (error, stackTrace) {
    developer.log(
      'Unable to restore auth session during startup.',
      name: 'main',
      error: error,
      stackTrace: stackTrace,
    );
  }
  runApp(CursorApp(dependencies: dependencies));
}
