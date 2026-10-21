import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/storage/file_crypto.dart';
import '../data/wallet_models.dart';
import 'wallet_import_validation.dart';

class WalletDraft {
  WalletDraft._(this._directory, this._key, this._crypto, this.files);
  final Directory _directory;
  final SecretKey _key;
  final FileCrypto _crypto;
  final List<WalletDraftFile> files;

  static Future<void> purgeAbandoned({Directory? cacheRoot}) async {
    final root = cacheRoot ?? await getTemporaryDirectory();
    final pending = Directory('${root.path}/wallet_pending');
    if (await pending.exists()) await pending.delete(recursive: true);
  }

  static Future<WalletDraft> stage(
    List<WalletDocumentInput> sources, {
    required SecretKey key,
    Directory? cacheRoot,
  }) async {
    final root = cacheRoot ?? await getTemporaryDirectory();
    final pending = Directory('${root.path}/wallet_pending');
    await pending.create(recursive: true);
    final folder = await pending.createTemp('capture-');
    final crypto = FileCrypto();
    final files = <WalletDraftFile>[];
    try {
      for (var i = 0; i < sources.length; i++) {
        final source = sources[i];
        final length = await source.source.length();
        if (length > walletMaximumImportBytes) {
          throw const FormatException('La copia supera los 25 MB.');
        }
        final bytes = await source.source.readAsBytes();
        try {
          final mime = inspectWalletInput(bytes, length: bytes.length);
          final encrypted = File('${folder.path}/$i.prcf');
          await encrypted.writeAsBytes(
            await crypto.encryptBytes(bytes, key),
            flush: true,
          );
          files.add(WalletDraftFile(source.originalName, mime, encrypted));
        } finally {
          bytes.fillRange(0, bytes.length, 0);
        }
      }
      if (files.isEmpty) {
        throw const FormatException('No se seleccionaron p\u00e1ginas.');
      }
      return WalletDraft._(folder, key, crypto, List.unmodifiable(files));
    } catch (_) {
      if (await folder.exists()) await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<Uint8List> read(int index) async =>
      _crypto.decryptBytes(await files[index].encrypted.readAsBytes(), _key);

  Future<File> materialize(int index) async {
    final file = File(
      '${_directory.path}/view-$index.${files[index].isPdf ? 'pdf' : 'image'}',
    );
    final bytes = await read(index);
    return writeWalletPlaintext(file, bytes);
  }

  Future<void> dispose() async {
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}

// Owns the supplied buffer and app-created temporary, including partial writes.
Future<File> writeWalletPlaintext(File file, Uint8List bytes) async {
  try {
    await file.writeAsBytes(bytes, flush: true);
    return file;
  } catch (_) {
    if (await file.exists()) await file.delete();
    rethrow;
  } finally {
    bytes.fillRange(0, bytes.length, 0);
  }
}

class WalletDraftFile {
  const WalletDraftFile(this.name, this.mimeType, this.encrypted);
  final String name;
  final String mimeType;
  final File encrypted;
  bool get isPdf => mimeType == 'application/pdf';
}
