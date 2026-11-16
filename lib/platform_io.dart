import 'dart:typed_data';

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
}

void openExternal(String url) =>
    throw UnsupportedError('openExternal is only supported in the web build');

Future<List<PickedFile>> pickFiles() =>
    throw UnsupportedError('pickFiles is only supported in the web build');
