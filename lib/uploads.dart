import 'package:flutter/foundation.dart';

class UploadJob {
  final String pid, name;
  int total;
  int sent = 0;
  int state = 0;
  Object? error;
  final Future<void> Function(void Function(int sent, int total) onProgress)
      run;
  UploadJob(this.pid, this.name, this.total, this.run);
}

class UploadQueue extends ChangeNotifier {
  final jobs = <UploadJob>[];
  bool _draining = false;

  Future<void> enqueue(List<UploadJob> js) async {
    jobs.addAll(js);
    notifyListeners();
    if (_draining) return;
    _draining = true;
    try {
      while (true) {
        UploadJob? next;
        for (final j in jobs) {
          if (j.state == 0) {
            next = j;
            break;
          }
        }
        if (next == null) break;
        next.state = 1;
        notifyListeners();
        try {
          await next.run((s, t) {
            next!.sent = s;
            next.total = t;
            notifyListeners();
          });
          next.state = 2;
        } catch (e) {
          next.state = 3;
          next.error = e;
        }
        notifyListeners();
      }
      jobs.removeWhere((j) => j.state == 2);
      notifyListeners();
    } finally {
      _draining = false;
    }
  }

  void dismiss(UploadJob j) {
    jobs.remove(j);
    notifyListeners();
  }
}
