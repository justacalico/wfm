import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
}

void Function(String url)? openExternalForTesting;
Future<List<PickedFile>> Function()? pickFilesForTesting;

void openExternal(String url) {
  final f = openExternalForTesting;
  if (f != null) {
    f(url);
    return;
  }
  web.window.open(url, '_blank');
}

Future<List<PickedFile>> pickFiles() async {
  final test = pickFilesForTesting;
  if (test != null) return test();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';
  web.document.body?.appendChild(input);
  final done = Completer<List<PickedFile>>();
  void finish(List<PickedFile> files) {
    input.remove();
    if (!done.isCompleted) done.complete(files);
  }

  input.onChange.listen((_) async {
    final files = input.files;
    final out = <PickedFile>[];
    if (files != null) {
      for (var i = 0; i < files.length; i++) {
        final f = files.item(i)!;
        final buf = await f.arrayBuffer().toDart;
        out.add(PickedFile(f.name, buf.toDart.asUint8List()));
      }
    }
    finish(out);
  });
  web.EventStreamProviders.cancelEvent
      .forElement(input)
      .listen((_) => finish([]));
  input.click();
  return done.future;
}
