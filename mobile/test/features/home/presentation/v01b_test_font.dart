import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadV01bTestFont() async {
  // Match Android typography instead of treating Ahem glyph widths as defects.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Bold']) {
    final file = File('${artifacts.path}/material_fonts/Roboto-$weight.ttf');
    loader.addFont(
      file.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}
