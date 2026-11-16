import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _TolerantComparator implements GoldenFileComparator {
  _TolerantComparator(this._inner);

  final GoldenFileComparator _inner;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final inner = _inner;
    if (inner is! LocalFileComparator) {
      return inner.compare(imageBytes, golden);
    }
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await inner.getGoldenBytes(golden));
    if (!result.passed && result.diffPercent < 0.005) {
      debugPrint('golden $golden diff ${result.diffPercent} tolerated');
      return true;
    }
    return result.passed;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) =>
      _inner.update(golden, imageBytes);

  @override
  Uri getTestUri(Uri key, int? version) => _inner.getTestUri(key, version);
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = _TolerantComparator(goldenFileComparator);
  await testMain();
}
