const walletMaximumImportBytes = 25 * 1024 * 1024;

/// Signature inspection is followed by actual image/PDF decoding before save.
String inspectWalletInput(List<int> header, {required int length}) {
  if (length <= 0 || length > walletMaximumImportBytes) {
    throw const FormatException('La copia debe pesar como m\u00e1ximo 25 MB.');
  }
  bool starts(List<int> signature) =>
      header.length >= signature.length &&
      List.generate(
        signature.length,
        (i) => header[i] == signature[i],
      ).every((v) => v);
  if (starts([0x25, 0x50, 0x44, 0x46, 0x2d]) &&
      header.length >= 8 &&
      header[5] >= 0x31 &&
      header[5] <= 0x32 &&
      header[6] == 0x2e &&
      header[7] >= 0x30 &&
      header[7] <= 0x39) {
    return 'application/pdf';
  }
  if (starts([0xff, 0xd8, 0xff]) && header.length >= 4) return 'image/jpeg';
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (starts([82, 73, 70, 70]) &&
      header.length >= 12 &&
      header[8] == 87 &&
      header[9] == 69 &&
      header[10] == 66 &&
      header[11] == 80) {
    return 'image/webp';
  }
  throw const FormatException('Selecciona una imagen o un PDF compatible.');
}
