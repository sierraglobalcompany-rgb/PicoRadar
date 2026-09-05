import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadV01bToolsTestFont() async {
  // Use the SDK's Android font metrics rather than Ahem for layout evidence.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final loader = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    final file = File('${artifacts.path}/material_fonts/roboto-$weight.ttf');
    loader.addFont(file.readAsBytes().then(ByteData.sublistView));
  }
  await loader.load();
}
