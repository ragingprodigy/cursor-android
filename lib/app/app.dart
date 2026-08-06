import 'package:cursor/app/di.dart';
import 'package:cursor/app/router.dart';
import 'package:cursor/app/theme.dart';
import 'package:cursor/features/prompts/data/prompt_library_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class CursorApp extends HookWidget {
  const CursorApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final router = useMemoized(() => createAppRouter(dependencies), [
      dependencies,
    ]);

    useEffect(() {
      return router.dispose;
    }, [router]);

    return RepositoryProvider<PromptLibraryRepository>.value(
      value: dependencies.promptLibraryRepository,
      child: MaterialApp.router(
        title: 'Cursor',
        theme: CursorTheme.dark(),
        darkTheme: CursorTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
