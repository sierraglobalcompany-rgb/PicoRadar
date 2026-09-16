import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/wallet_import_validation.dart';
import '../application/wallet_providers.dart';
import '../application/wallet_session.dart';
import '../platform/wallet_platform.dart';

/// Callbacks read an immutable encrypted source, including after reauthorization.
class WalletViewSource {
  const WalletViewSource({
    required this.label,
    required this.mimeType,
    required this.readBytes,
    required this.materializePdf,
    this.onPdfPageCount,
  });

  final String label;
  final String mimeType;

  /// Transfers ownership of a fresh buffer. The viewer zeroes it after decoding.
  final Future<Uint8List> Function() readBytes;

  /// Transfers ownership of a NEW app-private plaintext PDF temporary file.
  /// Never return an original import, encrypted file or shared temporary path.
  /// The viewer deletes this file immediately after native openPdf completes.
  final Future<File> Function() materializePdf;

  /// Reports the validated native count in the current authorized epoch.
  /// Called again after reauthorization; never called for images or rejected PDFs.
  final void Function(int pageCount)? onPdfPageCount;
}

/// Push on the root navigator. With [onSave], this is also the import preview.
/// Sources must remain immutable for the route lifetime. The save callback owns
/// the durable write and must check the wallet epoch before committing it.
/// Successful saving pops this route with true; cancellation returns null.
class WalletViewer extends ConsumerStatefulWidget {
  const WalletViewer({
    required this.title,
    required this.sources,
    this.onSave,
    this.maxPdfPages,
    super.key,
  }) : assert(maxPdfPages == null || maxPdfPages > 0);

  final String title;
  final List<WalletViewSource> sources;
  final Future<void> Function()? onSave;

  /// Only applies to new-document previews; existing PDFs are never truncated.
  final int? maxPdfPages;

  @override
  ConsumerState<WalletViewer> createState() => _WalletViewerState();
}

class _WalletViewerState extends ConsumerState<WalletViewer>
    with WidgetsBindingObserver {
  late final WalletSession _session;
  late final WalletPlatform _platform;
  late final WalletScreenSecurity _security;
  late final List<WalletViewSource> _sources;
  final _secureOwner = Object();
  final _transform = TransformationController();
  final _pdfs = <int, WalletPdfDocument>{};
  final _buffers = <Uint8List>{};
  final _operations = <Future<void>>{};
  Future<void> _contentTail = Future<void>.value();
  ui.Image? _image;
  bool _secure = false;
  bool _loading = false;
  bool _validated = false;
  bool _saving = false;
  bool _closing = false;
  bool _disposed = false;
  bool _cleanupFailed = false;
  String? _error;
  String? _saveError;
  int _generation = 0;
  int? _loadedEpoch;
  int _source = 0;
  int _page = 0;
  int _rotation = 0;

  bool get _allowed =>
      !_disposed && !_closing && _secure && _session.accessAllowed;
  bool _current(int generation, int epoch) =>
      _allowed &&
      generation == _generation &&
      _session.isAuthorizedEpoch(epoch);

  @override
  void initState() {
    super.initState();
    _sources = List.unmodifiable(widget.sources);
    _session = ref.read(walletSessionProvider);
    _platform = ref.read(walletPlatformProvider);
    _security = ref.read(walletScreenSecurityProvider);
    _session.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _track(_prepare());
  }

  void _track(Future<void> operation) {
    _operations.add(operation);
    unawaited(operation.whenComplete(() => _operations.remove(operation)));
  }

  Future<void> _prepare() async {
    try {
      await _security.acquire(_secureOwner);
      if (_disposed) return;
      setState(() {
        _secure = true;
        _error = null;
      });
      _sessionChanged();
    } catch (_) {
      if (!_disposed) {
        setState(() {
          _secure = false;
          _error = 'No se pudo proteger esta pantalla. Intenta de nuevo.';
        });
      }
    }
  }

  void _sessionChanged() {
    if (_disposed) return;
    if (!_session.accessAllowed ||
        (_loadedEpoch != null && _loadedEpoch != _session.epoch)) {
      _clearContent();
    }
    if (_allowed && _loadedEpoch == null) {
      _loadedEpoch = _session.epoch;
      final epoch = _session.epoch;
      _loading = true;
      // A source may reuse its temporary filename. Finish old work before
      // rematerializing on reauthorization, including an outstanding save.
      _contentTail = _contentTail.then((_) async {
        if (_allowed && _session.isAuthorizedEpoch(epoch)) await _load();
      });
      _track(_contentTail);
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _session.lock();
    }
  }

  // RawImage bypasses Flutter's global ImageCache entirely. This state is the
  // sole owner of the decoded image; neither providers nor routes retain it.
  void _dropImage() {
    _image?.dispose();
    _image = null;
  }

  void _clearContent() {
    _generation++;
    _loadedEpoch = null;
    _validated = false;
    _loading = false;
    _error = null;
    _saveError = null;
    _dropImage();
    for (final bytes in _buffers) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _buffers.clear();
    final closing = <Future<void>>[];
    for (final pdf in _pdfs.values) {
      final operation = _closePdf(pdf);
      closing.add(operation);
      _track(operation);
    }
    if (closing.isNotEmpty) {
      _contentTail = Future.wait<void>([_contentTail, ...closing]).then((_) {});
    }
    _pdfs.clear();
    _source = 0;
    _page = 0;
    _rotation = 0;
    if (!_disposed) _transform.value = Matrix4.identity();
  }

  Future<void> _closePdf(WalletPdfDocument pdf) async {
    try {
      await _platform.closePdf(pdf.id);
    } catch (_) {
      _cleanupFailed = true;
      if (!_disposed) {
        _session.lock();
        setState(() => _error = 'No se pudo cerrar la copia de forma segura.');
      }
    }
  }

  Future<WalletPdfDocument?> _openPdf(
    WalletViewSource source,
    int generation,
    int epoch,
  ) async {
    File? temporary;
    WalletPdfDocument? document;
    try {
      try {
        temporary = await source.materializePdf();
        if (!_current(generation, epoch)) return null;
        document = await _platform.openPdf(temporary.path);
      } finally {
        // openPdf validates every page and copies to an unlinked native FD.
        // Only the file explicitly transferred by materializePdf is deleted.
        try {
          if (temporary != null && await temporary.exists()) {
            await temporary.delete();
          }
        } on FileSystemException {
          _cleanupFailed = true;
          rethrow;
        }
      }
      if (!_current(generation, epoch)) {
        await _closePdf(document);
        return null;
      }
      final maximum = widget.onSave == null ? null : widget.maxPdfPages;
      if (document.pageCount < 1 ||
          (maximum != null && document.pageCount > maximum)) {
        throw const FormatException('Invalid PDF page count.');
      }
      source.onPdfPageCount?.call(document.pageCount);
      return document;
    } catch (_) {
      if (document != null) await _closePdf(document);
      rethrow;
    }
  }

  Future<ui.Image?> _decode(
    Future<Uint8List> Function() read,
    String mime,
    int generation,
    int epoch,
  ) async {
    Uint8List? bytes;
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      bytes = await read();
      if (!_current(generation, epoch)) return null;
      _buffers.add(bytes);
      if (inspectWalletInput(bytes, length: bytes.length) != mime ||
          !mime.startsWith('image/')) {
        throw const FormatException('Invalid image content.');
      }
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      if (!_current(generation, epoch)) return null;
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (!_current(generation, epoch)) return null;
      final width = descriptor.width;
      final height = descriptor.height;
      if (width < 1 ||
          height < 1 ||
          width > 16384 ||
          height > 16384 ||
          width * height > 64 * 1024 * 1024) {
        throw const FormatException('Image dimensions exceed safe bounds.');
      }
      final largest = width > height ? width : height;
      final scale = largest > 2048 ? 2048 / largest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (width * scale).round().clamp(1, 2048),
        targetHeight: (height * scale).round().clamp(1, 2048),
      );
      if (!_current(generation, epoch)) return null;
      if (codec.frameCount != 1) {
        throw const FormatException(
          'Animated document images are unsupported.',
        );
      }
      decoded = (await codec.getNextFrame()).image;
      if (!_current(generation, epoch)) return null;
      final result = decoded;
      decoded = null;
      return result;
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      bytes?.fillRange(0, bytes.length, 0);
      _buffers.remove(bytes);
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final epoch = _session.epoch;
    _loading = true;
    _validated = false;
    _error = null;
    try {
      if (_sources.isEmpty || _cleanupFailed) {
        throw const FormatException('No readable document.');
      }
      for (var i = 0; i < _sources.length; i++) {
        if (!_current(generation, epoch)) return;
        final source = _sources[i];
        if (source.mimeType == 'application/pdf') {
          final pdf = await _openPdf(source, generation, epoch);
          if (pdf == null) return;
          if (!_current(generation, epoch)) {
            await _closePdf(pdf);
            return;
          }
          _pdfs[i] = pdf;
        } else {
          final image = await _decode(
            source.readBytes,
            source.mimeType,
            generation,
            epoch,
          );
          if (image == null) return;
          if (!_current(generation, epoch)) {
            image.dispose();
            return;
          }
          // Validate each face, retaining only the first visible image.
          if (i == 0) {
            _image = image;
          } else {
            image.dispose();
          }
        }
      }
      if (!_current(generation, epoch)) return;
      final firstPdf = _pdfs[0];
      if (firstPdf != null) {
        final image = await _decode(
          () => _platform.renderPdfPage(firstPdf.id, 0, 2048),
          'image/png',
          generation,
          epoch,
        );
        if (!_current(generation, epoch)) {
          image?.dispose();
          return;
        }
        _image = image;
      }
      if (!_current(generation, epoch)) return;
      if (_image == null) throw const FormatException('Unreadable document.');
      setState(() {
        _validated = true;
        _loading = false;
      });
    } catch (_) {
      if (_current(generation, epoch)) _showReadError();
    }
  }

  void _showReadError() {
    _clearContent();
    _loadedEpoch = _session.epoch;
    setState(
      () => _error = 'No se pudo leer la copia. Selecciona una imagen o un PDF v\u00e1lido.',
    );
  }

  Future<void> _showPage(int source, int page) async {
    if (!_allowed || _loading || _saving || !_validated) return;
    final generation = ++_generation;
    final epoch = _session.epoch;
    setState(() {
      _loading = true;
      _dropImage();
      _source = source;
      _page = page;
      _rotation = 0;
      _transform.value = Matrix4.identity();
    });
    try {
      final pdf = _pdfs[source];
      final item = _sources[source];
      final image = await _decode(
        pdf == null
            ? item.readBytes
            : () => _platform.renderPdfPage(pdf.id, page, 2048),
        pdf == null ? item.mimeType : 'image/png',
        generation,
        epoch,
      );
      if (!_current(generation, epoch)) {
        image?.dispose();
        return;
      }
      if (image == null) throw const FormatException('Unreadable page.');
      setState(() {
        _image = image;
        _loading = false;
      });
    } catch (_) {
      if (_current(generation, epoch)) _showReadError();
    }
  }

  void _navigatePage(int source, int page) {
    if (!_allowed || _loading || _saving || !_validated) return;
    _contentTail = _showPage(source, page);
    _track(_contentTail);
  }

  Future<void> _save() async {
    if (!_allowed || !_validated || _loading || _saving || _error != null) {
      return;
    }
    final generation = _generation;
    final epoch = _session.epoch;
    setState(() => _saving = true);
    var saved = false;
    try {
      await widget.onSave!();
      saved = true;
    } catch (_) {
      if (_current(generation, epoch)) {
        setState(
          () => _saveError = 'No se pudo guardar la copia. Intenta de nuevo.',
        );
      }
    } finally {
      if (!_disposed) setState(() => _saving = false);
    }
    if (mounted &&
        saved &&
        _current(generation, epoch) &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _unlock() async {
    if (!_secure) await _prepare();
    if (!_disposed && _secure && !_cleanupFailed) await _session.unlock();
  }

  @override
  void dispose() {
    _disposed = true;
    _session.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _clearContent();
    _transform.dispose();
    unawaited(_releaseAfterCleanup());
    super.dispose();
  }

  Future<void> _releaseAfterCleanup() async {
    while (_operations.isNotEmpty) {
      await Future.wait(_operations.toList());
    }
    // A failed native cleanup leaves the secure window enabled (fail closed).
    if (_cleanupFailed) return;
    try {
      await _security.release(_secureOwner);
    } catch (_) {
      _cleanupFailed = true;
    }
  }

  Widget _icon(String label, IconData icon, VoidCallback? action) => IconButton(
    tooltip: label,
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: action,
    icon: Icon(icon),
  );

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed && !_cleanupFailed;
    final ready = allowed && _validated && !_loading && !_saving;
    final count = _pdfs[_source]?.pageCount ?? 1;
    final hasPrevious = _source > 0 || _page > 0;
    final hasNext = _page + 1 < count || _source + 1 < _sources.length;
    final title = allowed ? widget.title : 'Documentos';
    final titleStyle =
        Theme.of(context).appBarTheme.titleTextStyle ??
        Theme.of(context).textTheme.titleLarge!;
    final titleLayout =
        TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 88).clamp(
            1,
            double.infinity,
          ),
        );
    final toolbarHeight = (titleLayout.height + 16).clamp(
      56.0,
      double.infinity,
    );
    titleLayout.dispose();
    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_disposed) {
          setState(() {
            _closing = true;
            _clearContent();
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: toolbarHeight,
          title: Text(title, style: titleStyle),
          leading: _icon(
            'Volver',
            Icons.arrow_back,
            _saving ? null : () => Navigator.of(context).maybePop(),
          ),
        ),
        body: SafeArea(
          child: !allowed
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 40),
                        const SizedBox(height: 16),
                        Text(
                          _error ??
                              _session.failureMessage ??
                              'Documentos protegidos',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (_session.busy)
                          const CircularProgressIndicator()
                        else if (!_cleanupFailed)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: () => _track(_unlock()),
                            icon: const Icon(Icons.lock_open),
                            label: const Text('Desbloquear'),
                          ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        'Copia de respaldo',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: _error != null
                          ? Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      size: 40,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(_error!, textAlign: TextAlign.center),
                                  ],
                                ),
                              ),
                            )
                          : _loading || _image == null
                          ? const Center(child: CircularProgressIndicator())
                          : ClipRect(
                              child: InteractiveViewer(
                                transformationController: _transform,
                                minScale: 1,
                                maxScale: 5,
                                child: Center(
                                  child: RotatedBox(
                                    quarterTurns: _rotation,
                                    child: Semantics(
                                      image: true,
                                      label: _sources[_source].label,
                                      child: RawImage(
                                        image: _image,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (_validated)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            _icon(
                              'Anterior',
                              Icons.chevron_left,
                              ready && hasPrevious
                                  ? () {
                                      final source = _page > 0
                                          ? _source
                                          : _source - 1;
                                      final page = _page > 0
                                          ? _page - 1
                                          : (_pdfs[source]?.pageCount ?? 1) - 1;
                                      _navigatePage(source, page);
                                    }
                                  : null,
                            ),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  '${_sources[_source].label}${count > 1 ? ' \u00b7 ${_page + 1}/$count' : ''}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            _icon(
                              'Siguiente',
                              Icons.chevron_right,
                              ready && hasNext
                                  ? () {
                                      _navigatePage(
                                        _page + 1 < count
                                            ? _source
                                            : _source + 1,
                                        _page + 1 < count ? _page + 1 : 0,
                                      );
                                    }
                                  : null,
                            ),
                            _icon(
                              'Rotar',
                              Icons.rotate_right,
                              ready
                                  ? () => setState(() {
                                      _rotation = (_rotation + 1) % 4;
                                      _transform.value = Matrix4.identity();
                                    })
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    if (_saveError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(_saveError!, textAlign: TextAlign.center),
                        ),
                      ),
                    if (widget.onSave != null)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('wallet-viewer-save'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(48, 48),
                            ),
                            onPressed: ready && _error == null
                                ? () {
                                    if (_saving ||
                                        _loading ||
                                        !_allowed ||
                                        !_validated) {
                                      return;
                                    }
                                    setState(() => _saveError = null);
                                    _contentTail = _save();
                                    _track(_contentTail);
                                  }
                                : null,
                            icon: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Guardando...' : 'Guardar copia',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
