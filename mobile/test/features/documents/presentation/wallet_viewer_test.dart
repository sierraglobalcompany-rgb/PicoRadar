import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_providers.dart';
import 'package:picoradar/features/documents/application/wallet_session.dart';
import 'package:picoradar/features/documents/platform/wallet_platform.dart';
import 'package:picoradar/features/documents/presentation/wallet_viewer.dart';

const _title = 'Conductor privado';
final _saveFinder = find.byKey(const ValueKey('wallet-viewer-save'));

Uint8List _png() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8A'
  'AQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  late _Platform platform;
  late _Authenticator authenticator;
  late WalletSession session;
  late _Harness harness;

  setUp(() async {
    platform = _Platform();
    authenticator = _Authenticator();
    session = WalletSession(
      authenticator: authenticator,
      preferences: _Preferences(),
    );
    await session.unlock();
    harness = _Harness(session, platform);
  });

  tearDown(() => session.dispose());

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _until(tester, () => platform.secureEvents.lastOrNull == false);
    expect(tester.takeException(), isNull);
  }

  testWidgets('secure acknowledgement precedes reads, title and pixels', (
    tester,
  ) async {
    final secure = Completer<void>();
    platform.secureWait = secure;
    final input = _Input();
    await harness.open(tester, [input.source()], onSave: () async {});
    await tester.pump();
    expect(input.reads, 0);
    expect(find.text(_title), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    secure.complete();
    await _until(tester, () => _canSave(tester));
    expect(platform.secureEvents.first, isTrue);
    expect(input.reads, 1);
    expect(input.materializations, 0);
    expect(input.buffers.single, everyElement(0));
    await close(tester);
  });

  testWidgets('secure failure never reads a source or exposes its label', (
    tester,
  ) async {
    platform.secureError = true;
    final input = _Input();
    await harness.open(tester, [input.source()], onSave: () async {});
    await _until(
      tester,
      () => find.textContaining('No se pudo proteger').evaluate().isNotEmpty,
    );
    expect(input.reads, 0);
    expect(find.text(_title), findsNothing);
    expect(_saveFinder, findsNothing);
    expect(find.byType(RawImage), findsNothing);
    platform.secureError = false;
    await close(tester);
  });

  testWidgets(
    'all faces must decode before saving and no image is materialized',
    (tester) async {
      final reverse = Completer<Uint8List>();
      final front = _Input();
      final back = _Input()..readOverride = () => reverse.future;
      var saves = 0;
      await harness.open(
        tester,
        [front.source(), back.source('Reverso')],
        onSave: () async {
          saves++;
        },
      );
      await _until(tester, () => back.reads == 1);
      expect(_canSave(tester), isFalse);
      expect(saves, 0);
      final bytes = _png();
      reverse.complete(bytes);
      await _until(tester, () => _canSave(tester));
      expect(bytes, everyElement(0));
      expect(front.materializations + back.materializations, 0);
      await tester.tap(_saveFinder);
      await _until(tester, () => harness.completed);
      expect(saves, 1);
      expect(harness.result, isTrue);
      await close(tester);
    },
  );

  for (final invalid in <String, List<int>>{
    'PNG signature without a decodable image': [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      0,
    ],
    'JPEG signature without a decodable image': [
      255,
      216,
      255,
      224,
      0,
      16,
      0,
      0,
    ],
    'non-image file': [1, 2, 3, 4, 5],
  }.entries) {
    testWidgets('rejects actual ${invalid.key} and never saves a replacement', (
      tester,
    ) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('wallet-invalid-'),
      ))!;
      final file = File('${root.path}/invalid');
      await tester.runAsync(() => file.writeAsBytes(invalid.value));
      final good = _Input();
      final bad = _Input()..readOverride = file.readAsBytes;
      var saves = 0;
      await harness.open(
        tester,
        [
          good.source(),
          bad.source(
            'Reverso',
            invalid.key.startsWith('JPEG') ? 'image/jpeg' : 'image/png',
          ),
        ],
        onSave: () async {
          saves++;
        },
      );
      await _until(
        tester,
        () => find.textContaining('No se pudo leer').evaluate().isNotEmpty,
      );
      expect(_canSave(tester), isFalse);
      expect(saves, 0);
      expect(find.byType(RawImage), findsNothing);
      expect(good.buffers.single, everyElement(0));
      expect(bad.buffers.single, everyElement(0));
      expect(await tester.runAsync(file.exists), isTrue);
      await close(tester);
      await tester.runAsync(() => root.delete(recursive: true));
    });
  }

  testWidgets(
    'bounds decoded image size and releases it on lock without image cache entries',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final png = (await tester.runAsync(() => _largePng(4096, 8)))!;
        final input = _Input()
          ..readOverride = () async => Uint8List.fromList(png);
        final cache = PaintingBinding.instance.imageCache;
        final cachedBefore = cache.currentSize;
        final liveBefore = cache.liveImageCount;
        await harness.open(tester, [input.source()]);
        await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
        final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
        expect(decoded.width, 2048);
        expect(decoded.height, 4);
        expect(cache.currentSize, cachedBefore);
        expect(cache.liveImageCount, liveBefore);
        expect(find.bySemanticsLabel('Frente').evaluate(), isNotEmpty);
        session.lock();
        expect(decoded.debugDisposed, isTrue);
        expect(input.buffers.single, everyElement(0));
        await tester.pump();
        expect(find.byType(RawImage), findsNothing);
        expect(find.text(_title), findsNothing);
        expect(find.bySemanticsLabel('Frente'), findsNothing);
        await close(tester);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'late image read after lock is wiped; reauthentication loads a fresh epoch',
    (tester) async {
      final delayed = Completer<Uint8List>();
      final input = _Input()..readOverride = () => delayed.future;
      await harness.open(tester, [input.source()], onSave: () async {});
      await _until(tester, () => input.reads == 1);
      session.lock();
      await tester.pump();
      final old = _png();
      input.readOverride = null;
      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      expect(input.reads, 1);
      delayed.complete(old);
      await _until(tester, () => _canSave(tester));
      expect(old, everyElement(0));
      expect(input.reads, 2);
      expect(authenticator.calls, 2);
      expect(input.buffers, everyElement(everyElement(0)));
      await close(tester);
    },
  );

  testWidgets('denied reauthentication never rereads or repaints content', (
    tester,
  ) async {
    final input = _Input();
    await harness.open(tester, [input.source()]);
    await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
    session.lock();
    authenticator.result = WalletAuthenticationResult.cancelled;
    await tester.pump();
    await tester.tap(find.text('Desbloquear'));
    await _until(tester, () => session.failure != null);
    expect(input.reads, 1);
    expect(find.byType(RawImage), findsNothing);
    expect(find.text(_title), findsNothing);
    await close(tester);
  });

  testWidgets(
    'closing during read wipes late bytes before releasing security',
    (tester) async {
      final delayed = Completer<Uint8List>();
      final input = _Input()..readOverride = () => delayed.future;
      await harness.open(tester, [input.source()]);
      await _until(tester, () => input.reads == 1);
      await tester.pumpWidget(const SizedBox());
      expect(platform.secureEvents, [true]);
      final bytes = _png();
      delayed.complete(bytes);
      await _until(tester, () => platform.secureEvents.last == false);
      expect(bytes, everyElement(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'front/back and visual rotation release the old image and reset zoom',
    (tester) async {
      final front = _Input();
      final back = _Input();
      await harness.open(tester, [front.source(), back.source('Reverso')]);
      await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
      final first = tester.widget<RawImage>(find.byType(RawImage)).image!;
      final transform = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      transform.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.tap(find.byTooltip('Rotar'));
      await tester.pump();
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        1,
      );
      expect(transform.value, Matrix4.identity());
      await tester.tap(find.byTooltip('Siguiente'));
      await _until(
        tester,
        () => back.reads == 2 && find.byType(RawImage).evaluate().isNotEmpty,
      );
      expect(first.debugDisposed, isTrue);
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        0,
      );
      expect(find.text('Reverso'), findsOneWidget);
      await tester.tap(find.byTooltip('Anterior'));
      await _until(
        tester,
        () => front.reads == 2 && find.byType(RawImage).evaluate().isNotEmpty,
      );
      expect(find.text('Frente'), findsOneWidget);
      await close(tester);
    },
  );

  testWidgets(
    'legacy PDF keeps all pages; deletes only materialized copy before rendering',
    (tester) async {
      final files = (await tester.runAsync(_PdfFiles.create))!;
      platform.pages = 4;
      platform.expectedTemp = files.temporary;
      await harness.open(tester, [files.source], maxPdfPages: 2);
      await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
      expect(platform.rendered, [(0, 2048)]);
      expect(files.pageCounts, [4]);
      expect(await tester.runAsync(files.temporary.exists), isFalse);
      expect(await tester.runAsync(files.original.exists), isTrue);
      for (var page = 1; page < 4; page++) {
        await tester.tap(find.byTooltip('Siguiente'));
        await _until(
          tester,
          () =>
              platform.rendered.length == page + 1 &&
              find.byType(RawImage).evaluate().isNotEmpty,
        );
      }
      expect(platform.rendered, [(0, 2048), (1, 2048), (2, 2048), (3, 2048)]);
      expect(tester.widget<IconButton>(_button('Siguiente')).onPressed, isNull);
      session.lock();
      await _until(tester, () => platform.closed.length == 1);
      expect(find.byType(RawImage), findsNothing);
      await close(tester);
      expect(platform.closed, ['pdf-1']);
      await tester.runAsync(files.dispose);
    },
  );

  testWidgets('new restricted preview rejects over-two-page PDF without save', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    platform.pages = 3;
    var saves = 0;
    await harness.open(
      tester,
      [files.source],
      maxPdfPages: 2,
      onSave: () async {
        saves++;
      },
    );
    await _until(
      tester,
      () => find.textContaining('No se pudo leer').evaluate().isNotEmpty,
    );
    expect(platform.closed, ['pdf-1']);
    expect(platform.rendered, isEmpty);
    expect(files.pageCounts, isEmpty);
    expect(_canSave(tester), isFalse);
    expect(saves, 0);
    expect(await tester.runAsync(files.temporary.exists), isFalse);
    await close(tester);
    await tester.runAsync(files.dispose);
  });

  testWidgets('native PDF rejection deletes temporary and sanitizes errors', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    platform.openError = const WalletPlatformException(
      'corrupt /private/id.pdf',
    );
    await harness.open(tester, [files.source], onSave: () async {});
    await _until(
      tester,
      () => find.textContaining('No se pudo leer').evaluate().isNotEmpty,
    );
    expect(await tester.runAsync(files.temporary.exists), isFalse);
    expect(await tester.runAsync(files.original.exists), isTrue);
    expect(_canSave(tester), isFalse);
    expect(find.textContaining('/private'), findsNothing);
    expect(platform.rendered, isEmpty);
    expect(files.pageCounts, isEmpty);
    await close(tester);
    await tester.runAsync(files.dispose);
  });

  testWidgets('lock during native open closes late FD without rendering', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    final pending = Completer<WalletPdfDocument>();
    platform.openWait = pending;
    await harness.open(tester, [files.source]);
    await _until(tester, () => platform.opens == 1);
    session.lock();
    pending.complete(const WalletPdfDocument(id: 'late-pdf', pageCount: 4));
    await _until(tester, () => platform.closed.contains('late-pdf'));
    expect(await tester.runAsync(files.temporary.exists), isFalse);
    expect(platform.rendered, isEmpty);
    expect(find.byType(RawImage), findsNothing);
    expect(files.pageCounts, isEmpty);
    await close(tester);
    await tester.runAsync(files.dispose);
  });

  for (final pageCount in [1, 2]) {
    testWidgets('preview reports actual $pageCount-page PDF before save', (
      tester,
    ) async {
      final files = (await tester.runAsync(_PdfFiles.create))!;
      final rendering = Completer<Uint8List>();
      platform.pages = pageCount;
      platform.renderWait = rendering;
      await harness.open(
        tester,
        [files.source],
        maxPdfPages: 2,
        onSave: () async {},
      );
      await _until(tester, () => platform.rendered.isNotEmpty);
      expect(files.pageCounts, [pageCount]);
      expect(await tester.runAsync(files.temporary.exists), isFalse);
      expect(_canSave(tester), isFalse);
      rendering.complete(_png());
      await _until(tester, () => _canSave(tester));
      expect(files.pageCounts, [pageCount]);
      await close(tester);
      await tester.runAsync(files.dispose);
    });
  }

  testWidgets(
    'old PDF epoch cannot publish a stale count after reauthorization',
    (tester) async {
      final files = (await tester.runAsync(_PdfFiles.create))!;
      final opening = Completer<WalletPdfDocument>();
      platform.openWait = opening;
      await harness.open(tester, [files.source]);
      await _until(tester, () => platform.opens == 1);
      session.lock();
      await tester.pump();
      await tester.tap(find.text('Desbloquear'));
      await tester.pump();
      platform.openWait = null;
      platform.pages = 2;
      opening.complete(const WalletPdfDocument(id: 'old-epoch', pageCount: 9));
      await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
      expect(files.pageCounts, [2]);
      expect(platform.closed, ['old-epoch']);
      await close(tester);
      await tester.runAsync(files.dispose);
    },
  );

  testWidgets('PDF open finishing after disposal never publishes page count', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    final opening = Completer<WalletPdfDocument>();
    platform.openWait = opening;
    await harness.open(tester, [files.source]);
    await _until(tester, () => platform.opens == 1);
    await tester.pumpWidget(const SizedBox());
    opening.complete(const WalletPdfDocument(id: 'disposed-pdf', pageCount: 2));
    await _until(tester, () => platform.secureEvents.last == false);
    expect(files.pageCounts, isEmpty);
    expect(platform.closed, ['disposed-pdf']);
    expect(await tester.runAsync(files.temporary.exists), isFalse);
    expect(tester.takeException(), isNull);
    await tester.runAsync(files.dispose);
  });

  testWidgets('lock during page render clears PNG and closes native document', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    final pending = Completer<Uint8List>();
    platform.renderWait = pending;
    await harness.open(tester, [files.source]);
    await _until(tester, () => platform.rendered.isNotEmpty);
    session.lock();
    final bytes = _png();
    pending.complete(bytes);
    await _until(tester, () => bytes.every((byte) => byte == 0));
    expect(platform.closed, ['pdf-1']);
    expect(find.byType(RawImage), findsNothing);
    expect(find.text(_title), findsNothing);
    await close(tester);
    await tester.runAsync(files.dispose);
  });

  testWidgets(
    'late PDF materialization after lock is deleted without opening',
    (tester) async {
      final files = (await tester.runAsync(_PdfFiles.create))!;
      final pending = Completer<File>();
      var requested = false;
      final source = WalletViewSource(
        label: 'PDF',
        mimeType: 'application/pdf',
        readBytes: () => throw StateError('Unexpected byte read'),
        materializePdf: () {
          requested = true;
          return pending.future;
        },
      );
      await harness.open(tester, [source]);
      await _until(tester, () => requested);
      session.lock();
      final temporary = (await tester.runAsync(
        () => files.original.copy(files.temporary.path),
      ))!;
      pending.complete(temporary);
      await _until(tester, () => !temporary.existsSync());
      expect(platform.opens, 0);
      expect(platform.rendered, isEmpty);
      expect(find.byType(RawImage), findsNothing);
      await close(tester);
      await tester.runAsync(files.dispose);
    },
  );

  testWidgets('reauthorized PDF waits for old native close before reopening', (
    tester,
  ) async {
    final files = (await tester.runAsync(_PdfFiles.create))!;
    await harness.open(tester, [files.source]);
    await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
    final closing = Completer<void>();
    platform.closeWait = closing;
    session.lock();
    await tester.pump();
    await tester.tap(find.text('Desbloquear'));
    await tester.pump();
    expect(platform.opens, 1);
    platform.closeWait = null;
    closing.complete();
    await _until(
      tester,
      () => platform.opens == 2 && find.byType(RawImage).evaluate().isNotEmpty,
    );
    expect(platform.closed, ['pdf-1']);
    await close(tester);
    expect(platform.closed, ['pdf-1', 'pdf-2']);
    await tester.runAsync(files.dispose);
  });

  testWidgets(
    'native close failure hides private content and retains secure flag',
    (tester) async {
      final files = (await tester.runAsync(_PdfFiles.create))!;
      await harness.open(tester, [files.source]);
      await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
      platform.closeError = true;
      session.lock();
      await _until(
        tester,
        () => find.textContaining('No se pudo cerrar').evaluate().isNotEmpty,
      );
      expect(find.text(_title), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('Desbloquear'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(platform.secureEvents, everyElement(isTrue));
      expect(tester.takeException(), isNull);
      await tester.runAsync(files.dispose);
    },
  );

  testWidgets(
    'failed save stays open, retries once, and successful save pops',
    (tester) async {
      var saves = 0;
      await harness.open(
        tester,
        [_Input().source()],
        onSave: () async {
          saves++;
          if (saves == 1) throw StateError('private details must never appear');
        },
      );
      await _until(tester, () => _canSave(tester));
      await tester.tap(_saveFinder);
      await _until(
        tester,
        () => find.textContaining('No se pudo guardar').evaluate().isNotEmpty,
      );
      expect(harness.completed, isFalse);
      expect(find.textContaining('private details'), findsNothing);
      await tester.tap(_saveFinder);
      await _until(tester, () => harness.completed);
      expect(saves, 2);
      expect(harness.result, isTrue);
      await close(tester);
    },
  );

  testWidgets(
    'save busy prevents repeat/back and late completion after disposal is inert',
    (tester) async {
      final saving = Completer<void>();
      var saves = 0;
      await harness.open(
        tester,
        [_Input().source()],
        onSave: () {
          saves++;
          return saving.future;
        },
      );
      await _until(tester, () => _canSave(tester));
      await tester.tap(_saveFinder);
      await tester.pump();
      expect(_canSave(tester), isFalse);
      expect(tester.widget<IconButton>(_button('Volver')).onPressed, isNull);
      expect(await harness.navigator.currentState!.maybePop(), isTrue);
      expect(harness.completed, isFalse);
      expect(saves, 1);
      await tester.pumpWidget(const SizedBox());
      expect(platform.secureEvents.last, isTrue);
      saving.complete();
      await _until(tester, () => platform.secureEvents.last == false);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('save completion in a revoked epoch cannot dismiss lock screen', (
    tester,
  ) async {
    final saving = Completer<void>();
    await harness.open(tester, [
      _Input().source(),
    ], onSave: () => saving.future);
    await _until(tester, () => _canSave(tester));
    await tester.tap(_saveFinder);
    session.lock();
    saving.complete();
    await tester.pump();
    await tester.pump();
    expect(harness.completed, isFalse);
    expect(find.byType(RawImage), findsNothing);
    expect(find.text(_title), findsNothing);
    await close(tester);
  });

  testWidgets('save completion cannot pop another route pushed above viewer', (
    tester,
  ) async {
    final saving = Completer<void>();
    await harness.open(tester, [
      _Input().source(),
    ], onSave: () => saving.future);
    await _until(tester, () => _canSave(tester));
    await tester.tap(_saveFinder);
    unawaited(
      harness.navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Otra pantalla')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    saving.complete();
    await tester.pumpAndSettle();
    expect(find.text('Otra pantalla'), findsOneWidget);
    expect(harness.completed, isFalse);
    await close(tester);
  });

  testWidgets(
    'background relocks and secure owner survives another owner release',
    (tester) async {
      final security = WalletScreenSecurity(platform);
      final otherOwner = Object();
      await security.acquire(otherOwner);
      harness.security = security;
      await harness.open(tester, [_Input().source()]);
      await _until(tester, () => find.byType(RawImage).evaluate().isNotEmpty);
      await security.release(otherOwner);
      expect(platform.secureEvents, everyElement(isTrue));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(session.accessAllowed, isFalse);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text(_title), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await close(tester);
    },
  );

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets(
      '48dp controls fit $width at large text without navigation chrome',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        harness.textScale = 2;
        await harness.open(tester, [
          _Input().source(),
          _Input().source('Reverso'),
        ], onSave: () async {});
        await _until(tester, () => _canSave(tester));
        for (final label in ['Volver', 'Anterior', 'Siguiente', 'Rotar']) {
          final size = tester.getSize(_button(label));
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
        }
        expect(find.text('Copia de respaldo'), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(BottomNavigationBar), findsNothing);
        expect(tester.takeException(), isNull);
        await close(tester);
      },
    );
  }
}

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == label,
);

bool _canSave(WidgetTester tester) =>
    _saveFinder.evaluate().isNotEmpty &&
    tester.widget<FilledButton>(_saveFinder).onPressed != null;

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (done()) return;
  }
  fail('Viewer did not reach the expected observable state.');
}

Future<Uint8List> _largePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.red, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

class _Input {
  int reads = 0;
  int materializations = 0;
  final buffers = <Uint8List>[];
  Future<Uint8List> Function()? readOverride;

  WalletViewSource source([
    String label = 'Frente',
    String mime = 'image/png',
  ]) => WalletViewSource(
    label: label,
    mimeType: mime,
    readBytes: () async {
      reads++;
      final bytes = await (readOverride?.call() ?? Future.value(_png()));
      buffers.add(bytes);
      return bytes;
    },
    materializePdf: () async {
      materializations++;
      throw StateError('Images must never be materialized by the viewer.');
    },
  );
}

class _Harness {
  _Harness(this.session, this.platform);
  final WalletSession session;
  final _Platform platform;
  final navigator = GlobalKey<NavigatorState>();
  WalletScreenSecurity? security;
  double textScale = 1;
  bool completed = false;
  bool? result;

  Future<void> open(
    WidgetTester tester,
    List<WalletViewSource> sources, {
    Future<void> Function()? onSave,
    int? maxPdfPages,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          walletSessionProvider.overrideWithValue(session),
          walletPlatformProvider.overrideWithValue(platform),
          if (security != null)
            walletScreenSecurityProvider.overrideWithValue(security!),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(body: Text('Billetera')),
        ),
      ),
    );
    unawaited(
      navigator.currentState!
          .push<bool>(
            MaterialPageRoute(
              builder: (_) => WalletViewer(
                title: _title,
                sources: sources,
                onSave: onSave,
                maxPdfPages: maxPdfPages,
              ),
            ),
          )
          .then((value) {
            completed = true;
            result = value;
          }),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

class _Authenticator implements WalletDeviceAuthenticator {
  var calls = 0;
  WalletAuthenticationResult result = WalletAuthenticationResult.success;
  @override
  Future<bool> canAuthenticate() async => true;
  @override
  Future<WalletAuthenticationResult> authenticate() async {
    calls++;
    return result;
  }
}

class _Preferences implements WalletSecurityPreferencesStore {
  @override
  Future<WalletSecurityPreferences> read() async =>
      const WalletSecurityPreferences(protectionEnabled: true, offerSeen: true);
  @override
  Future<void> write(WalletSecurityPreferences preferences) async {}
}

class _Platform extends WalletPlatform {
  final secureEvents = <bool>[];
  final closed = <String>[];
  final rendered = <(int, int)>[];
  int pages = 1;
  int opens = 0;
  bool secureError = false;
  bool closeError = false;
  Object? openError;
  File? expectedTemp;
  Completer<void>? secureWait;
  Completer<WalletPdfDocument>? openWait;
  Completer<Uint8List>? renderWait;
  Completer<void>? closeWait;

  @override
  Future<void> setSecure(bool enabled) async {
    secureEvents.add(enabled);
    if (secureError && enabled) {
      throw const WalletPlatformException('unsupported');
    }
    if (enabled && secureWait != null) await secureWait!.future;
  }

  @override
  Future<WalletPdfDocument> openPdf(String path) async {
    opens++;
    final pending = openWait;
    final document = WalletPdfDocument(id: 'pdf-$opens', pageCount: pages);
    expect(secureEvents.last, isTrue);
    expect(await File(path).exists(), isTrue);
    if (openError != null) throw openError!;
    return pending?.future ?? Future.value(document);
  }

  @override
  Future<Uint8List> renderPdfPage(String id, int page, int width) async {
    if (expectedTemp != null) expect(await expectedTemp!.exists(), isFalse);
    expect(width, lessThanOrEqualTo(2048));
    rendered.add((page, width));
    return renderWait?.future ?? Future.value(_png());
  }

  @override
  Future<void> closePdf(String id) async {
    closed.add(id);
    if (closeError) throw const WalletPlatformException('close_failed');
    if (closeWait != null) await closeWait!.future;
  }
}

class _PdfFiles {
  _PdfFiles(this.root, this.original, this.temporary);
  final Directory root;
  final File original;
  final File temporary;
  final pageCounts = <int>[];
  static Future<_PdfFiles> create() async {
    final root = await Directory.systemTemp.createTemp('wallet-pdf-viewer-');
    final original = File('${root.path}/original.pdf');
    await original.writeAsString('%PDF-1.7\ntruncated fixture');
    return _PdfFiles(root, original, File('${root.path}/private-preview.pdf'));
  }

  WalletViewSource get source => WalletViewSource(
    label: 'PDF',
    mimeType: 'application/pdf',
    readBytes: () => throw StateError('PDFs must use the native bridge.'),
    materializePdf: () => original.copy(temporary.path),
    onPdfPageCount: pageCounts.add,
  );
  Future<void> dispose() => root.delete(recursive: true);
}
