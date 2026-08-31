import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/app_secure_storage.dart';
import '../../../core/storage/file_crypto.dart';

enum PrivateVehicleDocumentType {
  soat('soat', 'SOAT'),
  rtm('rtm', 'RTM');

  const PrivateVehicleDocumentType(this.value, this.label);

  final String value;
  final String label;

  static PrivateVehicleDocumentType fromValue(String value) {
    return switch (value) {
      'soat' => PrivateVehicleDocumentType.soat,
      'rtm' => PrivateVehicleDocumentType.rtm,
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
  static const allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};

  final DirectoryResolver _rootDirectory;
  final DirectoryResolver _cacheDirectory;
  final SecretKeyResolver _masterKey;
  final FileCrypto _fileCrypto;
  final DateTime Function() _now;
  final DocumentIdGenerator _idGenerator;

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

    final root = await _storeRoot();
    final current = await get(vehicleId: vehicleId, documentType: documentType);
    final documentId = _idGenerator();
    final relativePath =
        'docs/${documentType.value}/$vehicleId/$documentId.prcf';
    final destination = File('${root.path}/$relativePath');
    final key = await _masterKey();
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
    if (current != null) {
      await _deleteEncryptedFile(current);
    }
    return metadata;
  }

  Future<File> decryptForView(PrivateVehicleDocumentMetadata metadata) async {
    final encrypted = await _encryptedFile(metadata);
    final cacheRoot = await _viewerRoot();
    final viewFile = File(
      '${cacheRoot.path}/${metadata.documentId}/${metadata.originalName}',
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
    final documents = await _readIndex();
    await _writeIndex([
      for (final document in documents)
        if (document.documentId != metadata.documentId) document,
    ]);
    await _deleteEncryptedFile(metadata);
    final cacheRoot = await _viewerRoot();
    final cached = Directory('${cacheRoot.path}/${metadata.documentId}');
    if (await cached.exists()) {
      await cached.delete(recursive: true);
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
      return const [];
    }
    return decoded
        .whereType<Map<String, Object?>>()
        .map(PrivateVehicleDocumentMetadata.fromJson)
        .toList(growable: false);
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
    final temp = File('${indexFile.path}.tmp.${_now().microsecondsSinceEpoch}');
    try {
      await temp.writeAsBytes(encrypted, flush: true);
      if (await indexFile.exists()) {
        await indexFile.delete();
      }
      await temp.rename(indexFile.path);
    } catch (_) {
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  Future<File> _indexFile() async =>
      File('${(await _storeRoot()).path}/$_indexName');

  Future<File> _encryptedFile(PrivateVehicleDocumentMetadata metadata) async {
    return File(
      '${(await _storeRoot()).path}/${metadata.encryptedRelativePath}',
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
