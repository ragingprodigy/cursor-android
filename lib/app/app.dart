import 'package:flutter/material.dart';

class CursorApp extends StatelessWidget {
  const CursorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cursor',
      home: Scaffold(body: Center(child: Text('Cursor'))),
    );
  }
}
