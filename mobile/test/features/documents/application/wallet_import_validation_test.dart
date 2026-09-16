import 'package:flutter_test/flutter_test.dart';
import 'package:picoradar/features/documents/application/wallet_import_validation.dart';

void main() {
  test('rejects a renamed executable, truncated image, and oversized copy', () {
    expect(
      () => inspectWalletInput([77, 90, 0, 0], length: 4),
      throwsFormatException,
    );
    expect(
      () => inspectWalletInput([137, 80, 78, 71], length: 4),
      throwsFormatException,
    );
    expect(
      () => inspectWalletInput(
        '%PDF-1.7'.codeUnits,
        length: 25 * 1024 * 1024 + 1,
      ),
      throwsFormatException,
    );
  });
  test('detects actual PDF and image formats independent of filename', () {
    expect(
      inspectWalletInput('%PDF-1.7\n'.codeUnits, length: 100),
      'application/pdf',
    );
    expect(inspectWalletInput([255, 216, 255, 224], length: 100), 'image/jpeg');
    expect(
      inspectWalletInput([137, 80, 78, 71, 13, 10, 26, 10], length: 100),
      'image/png',
    );
    expect(
      inspectWalletInput('RIFF0000WEBP'.codeUnits, length: 100),
      'image/webp',
    );
  });
  test('PDF signature must contain version and not just a filename prefix', () {
    expect(
      () => inspectWalletInput('%PDF'.codeUnits, length: 100),
      throwsFormatException,
    );
  });
}
