import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

class PickedVehicleDocument {
  const PickedVehicleDocument({
    required this.file,
    required this.originalName,
    required this.mimeType,
  });

  final File file;
  final String originalName;
  final String mimeType;
}

abstract interface class VehicleDocumentGateway {
  Future<PickedVehicleDocument?> pickDocument();

  Future<bool> openDocument(File file);
}

class FilePickerVehicleDocumentGateway implements VehicleDocumentGateway {
  const FilePickerVehicleDocumentGateway();

  @override
  Future<PickedVehicleDocument?> pickDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    final picked = files.firstOrNull;
    final path = picked?.path;
    if (picked == null || path == null || path.trim().isEmpty) {
      return null;
    }
    return PickedVehicleDocument(
      file: File(path),
      originalName: picked.name,
      mimeType: picked.xFile.mimeType ?? _mimeForName(picked.name),
    );
  }

  @override
  Future<bool> openDocument(File file) async {
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done;
  }

  String _mimeForName(String name) {
    final extension = name.split('.').last.toLowerCase();
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }
}
