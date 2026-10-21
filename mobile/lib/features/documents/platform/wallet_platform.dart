import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class WalletCaptureFile {
  const WalletCaptureFile({
    required this.file,
    required this.originalName,
    required this.mimeType,
  });

  final File file;
  final String originalName;
  final String mimeType;

  String get path => file.path;
}

class WalletPdfDocument {
  const WalletPdfDocument({required this.id, required this.pageCount});

  final String id;
  final int pageCount;
}

class WalletPlatformException implements Exception {
  const WalletPlatformException(this.code);

  final String code;

  static const _codes = {
    'unsupported',
    'busy',
    'cancelled',
    'invalid_arguments',
    'size_limit',
    'invalid_file',
    'invalid_session',
    'invalid_pdf',
    'protected_pdf',
    'pdf_unavailable',
    'closed',
    'pdf_failed',
    'render_failed',
    'invalid_result',
    'storage_failed',
    'cleanup_failed',
    'platform_failed',
    'pdf_open_failed',
    'pdf_render_failed',
    'pdf_closed',
    'scanner_services_missing',
    'scanner_services_update',
    'scanner_services_disabled',
    'scanner_services_unavailable',
    'scanner_services_updating',
    'scanner_start_failed',
    'scanner_launch_failed',
    'scanner_network',
    'scanner_timeout',
  };

  static String sanitizedCode(String code) =>
      _codes.contains(code) ? code : 'platform_failed';

  @override
  String toString() => 'WalletPlatformException($code)';
}

/// Android capabilities only. Session authorization and encryption belong to
/// the wallet workflow. Never display scan results before encrypting them,
/// including results arriving after authorization has been revoked.
class WalletPlatform {
  const WalletPlatform({
    this._channel = const MethodChannel('co.picoradar.app/wallet'),
  });

  final MethodChannel _channel;

  static const maxInputBytes = 25 * 1024 * 1024;
  static const maxRenderWidth = 2048;

  /// Returns app-private, temporary JPEGs, or null on cancellation. The caller
  /// must encrypt immediately and delete these paths in a finally block.
  Future<List<WalletCaptureFile>?> scan({int maxPages = 2}) async {
    if (maxPages < 1 || maxPages > 2) {
      throw ArgumentError.value(maxPages, 'maxPages');
    }
    final value = await _invoke<Object?>('scan', {'maxPages': maxPages});
    if (value == null) return null;
    if (value is! List || value.isEmpty || value.length > maxPages) {
      throw const WalletPlatformException('invalid_result');
    }
    return List.unmodifiable(
      value.map((item) {
        if (item is! Map ||
            item['path'] is! String ||
            !(item['path'] as String).startsWith('/') ||
            item['originalName'] is! String ||
            item['mimeType'] != 'image/jpeg') {
          throw const WalletPlatformException('invalid_result');
        }
        return WalletCaptureFile(
          file: File(item['path'] as String),
          originalName: item['originalName'] as String,
          mimeType: item['mimeType'] as String,
        );
      }),
    );
  }

  /// Native cleanup accepts only scanner-owned paths, never imported files.
  Future<void> deleteScanTemps(List<String> paths) =>
      _invoke<void>('deleteScanTemps', {'paths': paths});

  /// A single session owner must aggregate scopes: viewer/preview always;
  /// protected wallet while unlocked. Await true before exposing content and
  /// clear only after every sensitive scope has hidden its content.
  Future<void> setSecure(bool enabled) =>
      _invoke<void>('setSecure', {'enabled': enabled});

  Future<String> noBackupDirectory() async {
    final path = await _invoke<Object?>('noBackupDirectory');
    if (path is! String || !path.startsWith('/')) {
      throw const WalletPlatformException('invalid_result');
    }
    return path;
  }

  /// Accepts only a local app-private file. Native code copies to an unlinked
  /// seekable temporary descriptor; the caller still owns/deletes [path].
  Future<WalletPdfDocument> openPdf(String path) async {
    if (!path.startsWith('/')) throw ArgumentError.value(path, 'path');
    final value = await _invoke<Object?>('openPdf', {'path': path});
    if (value is! Map ||
        value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['pageCount'] is! int ||
        (value['pageCount'] as int) < 1) {
      throw const WalletPlatformException('invalid_result');
    }
    return WalletPdfDocument(
      id: value['id'] as String,
      pageCount: value['pageCount'] as int,
    );
  }

  /// [page] is zero-based. Render one visible page at a time; discard PNG bytes
  /// on lock/close. Native code also bounds height and total decoded pixels.
  Future<Uint8List> renderPdfPage(String id, int page, int width) async {
    if (id.isEmpty || page < 0 || width < 1 || width > maxRenderWidth) {
      throw ArgumentError('Invalid PDF render request.');
    }
    final value = await _invoke<Object?>('renderPdfPage', {
      'id': id,
      'page': page,
      'width': width,
    });
    if (value is! Uint8List || value.isEmpty) {
      throw const WalletPlatformException('invalid_result');
    }
    return value;
  }

  Future<void> closePdf(String id) async {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    await _invoke<void>('closePdf', {'id': id});
  }

  Future<T?> _invoke<T>(String method, [Map<String, Object>? arguments]) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const WalletPlatformException('unsupported');
    }
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const WalletPlatformException('unsupported');
    } on PlatformException catch (error) {
      // Native messages/details may contain file paths; expose only a code.
      throw WalletPlatformException(
        WalletPlatformException.sanitizedCode(error.code),
      );
    }
  }
}
