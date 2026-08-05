import 'package:cursor/app/app.dart';
import 'package:cursor/app/di.dart';
import 'package:cursor/core/config/app_config.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  final dependencies = await AppDependencies.create(config);
  await dependencies.authSession.restore();
  runApp(CursorApp(dependencies: dependencies));
}
