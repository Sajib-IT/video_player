import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_player_app/app.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/player/services/media_kit_player_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final databaseHelper = DatabaseHelper.instance;
  final playerService = MediaKitPlayerService();

  runApp(
    CineVaultApp(
      playerService: playerService,
      databaseHelper: databaseHelper,
    ),
  );

  // Warm up SQLite and libmpv after the first Flutter frame is scheduled,
  // avoiding startup ANR and media_kit's VideoController post-frame deadlock.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(databaseHelper.database);
    unawaited(playerService.initialize());
  });
}
