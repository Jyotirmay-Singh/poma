import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'font_support.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Every widget test uses the shipped font metrics, including tests that do
  // not save captures. Ahem is unsuitable for verifying production layouts.
  setUpAll(loadPomaTestFonts);
  await testMain();
}
