import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'data/db/database.dart';
import 'data/repositories/break_repo.dart';
import 'domain/movement_manifest.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  final documentsDir = await getApplicationDocumentsDirectory();
  final manifest = MovementManifest.parse(
      await rootBundle.loadString('assets/pictograms/own/manifest.json'));

  // Pause di sistema riscritte dal codice a ogni avvio (spec §7).
  await BreakRepo(db).syncBuiltins();

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      documentsDirProvider.overrideWithValue(documentsDir),
      manifestProvider.overrideWithValue(manifest),
    ],
    child: const PausaAttivaApp(),
  ));
}

class PausaAttivaApp extends StatelessWidget {
  const PausaAttivaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Pausa Attiva',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const HomeScreen(),
      );
}
