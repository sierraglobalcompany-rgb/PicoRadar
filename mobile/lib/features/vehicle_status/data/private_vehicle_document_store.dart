import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_secure_storage.dart';
import '../../../core/storage/file_crypto.dart';

enum PrivateVehicleDocumentType {
  trafficLicense('traffic_license', 'Licencia de tránsito'),
  soat('soat', 'SOAT'),
  rtm('rtm', 'Tecnomecánica'),
  voluntaryInsurance('voluntary_insurance', 'Seguro voluntario'),
  salePurchase('sale_purchase', 'Compraventa'),
  appraisal('appraisal', 'Peritaje'),
  other('other', 'Otro');

  const PrivateVehicleDocumentType(this.value, this.label);

  final String value;
  final String label;

  static PrivateVehicleDocumentType fromValue(String value) {
    return switch (value) {
      'traffic_license' => PrivateVehicleDocumentType.trafficLicense,
      'soat' => PrivateVehicleDocumentType.soat,
      'rtm' => PrivateVehicleDocumentType.rtm,
      'voluntary_insurance' => PrivateVehicleDocumentType.voluntaryInsurance,
      'sale_purchase' => PrivateVehicleDocumentType.salePurchase,
      'appraisal' => PrivateVehicleDocumentType.appraisal,
      'other' => PrivateVehicleDocumentType.other,
      _ => throw ArgumentError.value(value, 'type', 'Unsupported document.'),
    };
  }
}

class PrivateVehicleDocumentMetadata {
  const PrivateVehicleDocumentMetadata({
    required this.documentId,
    required this.vehicleId,
    required this.documentType,
    required this.originalName,
    required this.mimeType,
    required this.importedAt,
    required this.encryptedRelativePath,
  });

  final String documentId;
  final String vehicleId;
  final PrivateVehicleDocumentType documentType;
  final String originalName;
  final String mimeType;
  final DateTime importedAt;
  final String encryptedRelativePath;

  Map<String, Object?> toJson() => {
    'documentId': documentId,
    'vehicleId': vehicleId,
    'documentType': documentType.value,
    'originalName': originalName,
    'mimeType': mimeType,
    'importedAt': importedAt.toUtc().toIso8601String(),
    'encryptedRelativePath': encryptedRelativePath,
  };

  static PrivateVehicleDocumentMetadata fromJson(Map<String, Object?> json) {
    return PrivateVehicleDocumentMetadata(
      documentId: json['documentId']! as String,
      vehicleId: json['vehicleId']! as String,
      documentType: PrivateVehicleDocumentType.fromValue(
        json['documentType']! as String,
      ),
      originalName: json['originalName']! as String,
      mimeType: json['mimeType']! as String,
      importedAt: DateTime.parse(json['importedAt']! as String).toUtc(),
      encryptedRelativePath: json['encryptedRelativePath']! as String,
    );
  }
}

typedef DirectoryResolver = Future<Directory> Function();
typedef SecretKeyResolver = Future<SecretKey> Function();
typedef DocumentIdGenerator = String Function();

class PrivateVehicleDocumentStore {
  PrivateVehicleDocumentStore({
    DirectoryResolver? rootDirectory,
    DirectoryResolver? cacheDirectory,
    SecretKeyResolver? masterKey,
    FileCrypto? fileCrypto,
    DateTime Function()? now,
    DocumentIdGenerator? idGenerator,
  }) : _rootDirectory = rootDirectory ?? _defaultRootDirectory,
       _cacheDirectory = cacheDirectory ?? _defaultCacheDirectory,
       _masterKey = masterKey ?? AppSecureStorage().getOrCreateFileMasterKey,
       _fileCrypto = fileCrypto ?? FileCrypto(),
       _now = now ?? DateTime.now,
       _idGenerator = idGenerator ?? _secureId;

  static const _indexName = 'index_v1.prcf';
  static const _storageFolder = 'vehicle_documents';
  static const _viewerFolder = 'vehicle_document_viewer';
  static const maxImportBytes = 25 * 1024 * 1024;
  static const allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};

  final DirectoryResolver _rootDirectory;
  final DirectoryResolver _cacheDirectory;
  final SecretKeyResolver _masterKey;
  final FileCrypto _fileCrypto;
  final DateTime Function() _now;
  final DocumentIdGenerator _idGenerator;
  Future<void> _mutationTail = Future<void>.value();

  Future<PrivateVehicleDocumentMetadata?> get({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
  }) async {
    final documents = await _readIndex();
    for (final document in documents) {
      if (document.vehicleId == vehicleId &&
          document.documentType == documentType) {
        return document;
      }
    }
    return null;
  }

  Future<List<PrivateVehicleDocumentMetadata>> listForVehicle(
    String vehicleId,
  ) async {
    final documents = await _readIndex();
    final filtered = [
      for (final document in documents)
        if (document.vehicleId == vehicleId) document,
    ];
    filtered.sort((left, right) {
      final leftIndex = PrivateVehicleDocumentType.values.indexOf(
        left.documentType,
      );
      final rightIndex = PrivateVehicleDocumentType.values.indexOf(
        right.documentType,
      );
      return leftIndex.compareTo(rightIndex);
    });
    return filtered;
  }

  Future<PrivateVehicleDocumentMetadata> importDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required File source,
    required String originalName,
    required String mimeType,
  }) async {
    final extension = _extension(
      originalName.isEmpty ? source.path : originalName,
    );
    if (!allowedExtensions.contains(extension)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'Unsupported file type.',
      );
    }
    if (!await source.exists()) {
      throw ArgumentError.value(source.path, 'source', 'File does not exist.');
    }
    final sourceLength = await source.length();
    if (sourceLength > maxImportBytes) {
      throw ArgumentError.value(
        sourceLength,
        'source',
        'Document exceeds the 25 MB local import limit.',
      );
    }

    return _runMutation(() async {
      final root = await _storeRoot();
      final current = await get(
        vehicleId: vehicleId,
        documentType: documentType,
      );
      if (current != null) {
        await purgeViewerCache(metadata: current);
      }
      final documentId = _idGenerator();
      final vehiclePathSegment = _safePathSegment(vehicleId);
      final relativePath =
          'docs/${documentType.value}/$vehiclePathSegment/$documentId.prcf';
      final destination = File('${root.path}/$relativePath');
      final key = await _masterKey();
      var indexCommitted = false;
      try {
        await _fileCrypto.encryptFile(
          source: source,
          destination: destination,
          key: key,
        );

        final metadata = PrivateVehicleDocumentMetadata(
          documentId: documentId,
          vehicleId: vehicleId,
          documentType: documentType,
          originalName: _safeName(
            originalName.isEmpty ? source.path : originalName,
          ),
          mimeType: mimeType.trim().isEmpty
              ? _mimeForExtension(extension)
              : mimeType,
          importedAt: _now().toUtc(),
          encryptedRelativePath: relativePath,
        );
        final documents = await _readIndex();
        final next = [
          for (final document in documents)
            if (document.vehicleId != vehicleId ||
                document.documentType != documentType)
              document,
          metadata,
        ];
        await _writeIndex(next);
        indexCommitted = true;
        if (current != null) {
          await _tryDeleteEncryptedFile(current);
        }
        return metadata;
      } catch (_) {
        if (!indexCommitted && await destination.exists()) {
          await destination.delete();
        }
        rethrow;
      }
    });
  }

  Future<PrivateVehicleDocumentMetadata> replaceDocument({
    required String vehicleId,
    required PrivateVehicleDocumentType documentType,
    required File source,
    required String originalName,
    required String mimeType,
  }) {
    return importDocument(
      vehicleId: vehicleId,
      documentType: documentType,
      source: source,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  Future<File> decryptForView(PrivateVehicleDocumentMetadata metadata) async {
    await purgeViewerCache();
    final encrypted = await _encryptedFile(metadata);
    final cacheRoot = await _viewerRoot();
    final viewFile = File(
      '${cacheRoot.path}/${_safePathSegment(metadata.documentId)}/${_safeName(metadata.originalName)}',
    );
    final key = await _masterKey();
    await _fileCrypto.decryptFile(
      source: encrypted,
      destination: viewFile,
      key: key,
    );
    return viewFile;
  }

  Future<void> delete(PrivateVehicleDocumentMetadata metadata) async {
    await _runMutation(() async {
      final documents = await _readIndex();
      await _writeIndex([
        for (final document in documents)
          if (document.documentId != metadata.documentId) document,
      ]);
      await _deleteEncryptedFile(metadata);
      await purgeViewerCache(metadata: metadata);
    });
  }

  Future<void> deleteForVehicle(String vehicleId) async {
    final requestedVehicleId = vehicleId.trim();
    if (requestedVehicleId.isEmpty) {
      return;
    }

    await _runMutation(() async {
      final documents = await _readIndex();
      final targetDocuments = [
        for (final document in documents)
          if (document.vehicleId == requestedVehicleId) document,
      ];
      if (targetDocuments.isEmpty) {
        return;
      }

      for (final document in targetDocuments) {
        await purgeViewerCache(metadata: document);
        await _deleteEncryptedFile(document);
      }

      await _writeIndex([
        for (final document in documents)
          if (document.vehicleId != requestedVehicleId) document,
      ]);
    });
  }

  Future<void> purgeViewerCache({
    PrivateVehicleDocumentMetadata? metadata,
  }) async {
    final cacheRoot = await _viewerRoot();
    if (metadata != null) {
      final cached = Directory('${cacheRoot.path}/${metadata.documentId}');
      if (await cached.exists()) {
        await cached.delete(recursive: true);
      }
      return;
    }

    await for (final entity in cacheRoot.list()) {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<List<PrivateVehicleDocumentMetadata>> _readIndex() async {
    final indexFile = await _indexFile();
    if (!await indexFile.exists()) {
      return const [];
    }
    final key = await _masterKey();
    final raw = await _fileCrypto.decryptBytes(
      await indexFile.readAsBytes(),
      key,
    );
    final decoded = jsonDecode(utf8.decode(raw));
    if (decoded is! List) {
      throw const FormatException('Invalid private vehicle document index.');
    }
    return [
      for (final item in decoded)
        if (item is Map)
          PrivateVehicleDocumentMetadata.fromJson(
            Map<String, Object?>.from(item),
          )
        else
          throw const FormatException(
            'Invalid private vehicle document metadata.',
          ),
    ];
  }

  Future<void> _writeIndex(
    List<PrivateVehicleDocumentMetadata> documents,
  ) async {
    final indexFile = await _indexFile();
    final payload = utf8.encode(
      jsonEncode([for (final document in documents) document.toJson()]),
    );
    final key = await _masterKey();
    final encrypted = await _fileCrypto.encryptBytes(payload, key);
    await indexFile.parent.create(recursive: true);
    final stamp = _now().microsecondsSinceEpoch;
    final temp = File('${indexFile.path}.tmp.$stamp');
    final backup = File('${indexFile.path}.bak.$stamp');
    var backupCreated = false;
    try {
      await temp.writeAsBytes(encrypted, flush: true);
      if (await indexFile.exists()) {
        await indexFile.rename(backup.path);
        backupCreated = true;
      }
      await temp.rename(indexFile.path);
      if (backupCreated && await backup.exists()) {
        await _tryDeleteFile(backup);
      }
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      if (backupCreated && await backup.exists() && !await indexFile.exists()) {
        await backup.rename(indexFile.path);
      }
      rethrow;
    }
  }

  Future<File> _indexFile() async =>
      File('${(await _storeRoot()).path}/$_indexName');

  Future<File> _encryptedFile(PrivateVehicleDocumentMetadata metadata) async {
    return File(
      '${(await _storeRoot()).path}/${_checkedRelativePath(metadata.encryptedRelativePath)}',
    );
  }

  Future<void> _deleteEncryptedFile(
    PrivateVehicleDocumentMetadata metadata,
  ) async {
    final file = await _encryptedFile(metadata);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _tryDeleteEncryptedFile(
    PrivateVehicleDocumentMetadata metadata,
  ) async {
    try {
      await _deleteEncryptedFile(metadata);
    } catch (_) {
      return;
    }
  }

  Future<T> _runMutation<T>(Future<T> Function() action) {
    final previous = _mutationTail;
    final gate = Completer<void>();
    _mutationTail = gate.future;
    return (() async {
      await previous;
      try {
        return await action();
      } finally {
        gate.complete();
      }
    })();
  }

  Future<Directory> _storeRoot() async {
    final base = await _rootDirectory();
    final root = Directory('${base.path}/$_storageFolder');
    await root.create(recursive: true);
    return root;
  }

  Future<Directory> _viewerRoot() async {
    final base = await _cacheDirectory();
    final root = Directory('${base.path}/$_viewerFolder');
    await root.create(recursive: true);
    return root;
  }

  static Future<Directory> _defaultRootDirectory() async {
    return getApplicationSupportDirectory();
  }

  static Future<Directory> _defaultCacheDirectory() async {
    return getTemporaryDirectory();
  }

  static String _extension(String path) {
    final name = _safeName(path);
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }

  static String _safeName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? 'documento.pdf' : name;
  }

  static String _safePathSegment(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return safe.isEmpty ? 'documento' : safe;
  }

  static String _checkedRelativePath(String relativePath) {
    final normalized = relativePath.trim().replaceAll('\\', '/');
    final segments = normalized.split('/');
    final hasUnsafeSegment = segments.any(
      (segment) => segment.isEmpty || segment == '.' || segment == '..',
    );
    if (normalized.startsWith('/') ||
        normalized.contains(':') ||
        hasUnsafeSegment) {
      throw const FormatException('Invalid encrypted document path.');
    }
    return normalized;
  }

  static Future<void> _tryDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  static String _mimeForExtension(String extension) {
    return switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
  }

  static String _secureId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
