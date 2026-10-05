import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';

/// Ends a full-app widget test: unmounts the app so every cubit closes and
/// stops watching drift before tearDown closes the database.
Future<void> unmountApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

/// An in-memory database for full-app widget tests. Its query streams stop
/// the moment their last listener leaves — by default drift waits one event
/// loop on a timer, which fake time never runs, so closing the database in
/// tearDown would wait forever.
AppDatabase testDatabase() => AppDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);
