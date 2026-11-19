import 'package:flutter_test/flutter_test.dart';
import 'package:wfm/uploads.dart';

void main() {
  test('queue drains in order, reports progress, prunes done', () async {
    final q = UploadQueue();
    final marks = <String>[];
    var notified = 0;
    q.addListener(() => notified++);
    await q.enqueue([
      UploadJob('p', 'a.bin', 4, (p) async {
        p(2, 4);
        p(4, 4);
        marks.add('a');
      }),
      UploadJob('p', 'b.bin', 2, (p) async {
        p(0, 2);
        marks.add('b');
      }),
    ]);
    expect(marks, ['a', 'b']);
    expect(q.jobs, isEmpty);
    expect(notified, greaterThan(3));
  });

  test('progress notifications are throttled, completion still lands',
      () async {
    final q = UploadQueue();
    var notified = 0;
    q.addListener(() => notified++);
    await q.enqueue([
      UploadJob('p', 'a.bin', 100, (p) async {
        for (var i = 1; i <= 100; i++) {
          p(i, 100);
        }
      }),
    ]);
    expect(notified, lessThan(50));
  });

  test('failed jobs stay until dismissed', () async {
    final q = UploadQueue();
    await q.enqueue([
      UploadJob('p', 'a.bin', 4, (p) async => throw 'disk full'),
    ]);
    expect(q.jobs.single.state, 3);
    expect('${q.jobs.single.error}', 'disk full');
    q.dismiss(q.jobs.single);
    expect(q.jobs, isEmpty);
  });

  test('enqueue while draining joins the run', () async {
    final q = UploadQueue();
    final done = <String>[];
    final run = q.enqueue([
      UploadJob('p', 'a', 1, (p) async {
        q.enqueue([
          UploadJob('p', 'b', 1, (p) async {
            done.add('b');
          })
        ]);
        done.add('a');
      }),
    ]);
    await run;
    expect(done, ['a', 'b']);
    expect(q.jobs, isEmpty);
  });
}
