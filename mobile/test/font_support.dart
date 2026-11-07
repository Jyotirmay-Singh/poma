import 'dart:io';
import 'package:flutter/services.dart';
import 'package:poma/ui/design_tokens.dart';

/// Captures use exactly the offline font assets shipped by the application.
Future<void> loadPomaTestFonts() async {
  final body = FontLoader(PomaType.family);
  for (final weight in ['Regular', 'Medium', 'Semibold']) {
    body.addFont(rootBundle.load('assets/fonts/SourceSans3-$weight.ttf'));
  }
  await body.load();
  // The production engine finds installed script fallbacks itself. The host
  // test renderer needs explicit registration to render multilingual fixtures.
  final japanese = File('C:/Windows/Fonts/YuGothR.ttc');
  if (Platform.isWindows && await japanese.exists()) {
    await (FontLoader('Yu Gothic')..addFont(
          Future.value(ByteData.sublistView(await japanese.readAsBytes())),
        ))
        .load();
  }
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
}
