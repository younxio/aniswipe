import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('discover_cache');
  await Hive.openBox('anime_cache');
  await Hive.openBox('favorites_cache');
  await Hive.openBox('offline_queue');
  await Hive.openBox('auth_box');

  runApp(
    const ProviderScope(
      child: AniSwipeApp(),
    ),
  );
}
