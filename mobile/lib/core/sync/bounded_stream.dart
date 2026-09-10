import 'dart:io';
import 'dart:typed_data';

Future<List<int>> collectBoundedBytes(
  Stream<List<int>> stream, {
  required int maxBytes,
  required String label,
}) async {
  final builder = BytesBuilder(copy: false);
  var received = 0;
  await for (final chunk in stream) {
    received = _checkedLength(received, chunk.length, maxBytes, label);
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Future<void> writeBoundedStream(
  Stream<List<int>> stream,
  File destination, {
  required int maxBytes,
  required String label,
}) async {
  final sink = destination.openWrite();
  var received = 0;
  try {
    await for (final chunk in stream) {
      received = _checkedLength(received, chunk.length, maxBytes, label);
      sink.add(chunk);
    }
    await sink.flush();
  } finally {
    await sink.close();
  }
}

int _checkedLength(int received, int next, int maxBytes, String label) {
  if (next > maxBytes - received) {
    throw BoundedStreamException('$label exceeds its $maxBytes byte limit.');
  }
  return received + next;
}

class BoundedStreamException implements Exception {
  const BoundedStreamException(this.message);

  final String message;
}
