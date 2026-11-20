import 'package:flutter/material.dart';

class ShowcaseCard extends StatelessWidget {
  final String title;
  final Widget child;
  const ShowcaseCard({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: 160, width: double.infinity, child: child),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ]),
    );
  }
}

class TimelineMock extends StatelessWidget {
  const TimelineMock({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(painter: _TimelinePainter(cs));
  }
}

class _TimelinePainter extends CustomPainter {
  final ColorScheme cs;
  _TimelinePainter(this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = cs.surfaceContainerHighest);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.42),
        Paint()..color = cs.surfaceContainerHigh);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w / 2, h * 0.21), width: 26, height: 30),
            const Radius.circular(4)),
        Paint()..color = cs.primary);
    final play = Path()
      ..moveTo(w / 2 - 4, h * 0.21 - 7)
      ..lineTo(w / 2 - 4, h * 0.21 + 7)
      ..lineTo(w / 2 + 7, h * 0.21)
      ..close();
    canvas.drawPath(play, Paint()..color = cs.onPrimary);
    final trackPaint = Paint()..color = cs.primary.withValues(alpha: 0.8);
    final track2 = Paint()..color = cs.tertiary.withValues(alpha: 0.7);
    final audio = Paint()..color = cs.secondary.withValues(alpha: 0.55);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.06, h * 0.55, w * 0.52, h * 0.11),
            const Radius.circular(3)),
        trackPaint);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.60, h * 0.55, w * 0.3, h * 0.11),
            const Radius.circular(3)),
        track2);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.15, h * 0.72, w * 0.34, h * 0.09),
            const Radius.circular(3)),
        audio);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.52, h * 0.72, w * 0.2, h * 0.09),
            const Radius.circular(3)),
        audio);
    canvas.drawRect(Rect.fromLTWH(w * 0.44, h * 0.44, 1.5, h * 0.5),
        Paint()..color = cs.error);
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.cs != cs;
}

class ScriptMock extends StatelessWidget {
  const ScriptMock({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(painter: _ScriptPainter(cs));
  }
}

class _ScriptPainter extends CustomPainter {
  final ColorScheme cs;
  _ScriptPainter(this.cs);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
        Offset.zero & size, Paint()..color = cs.surfaceContainerHighest);
    final page = Rect.fromLTWH(w * 0.17, h * 0.07, w * 0.66, h * 0.86);
    canvas.drawRect(page, Paint()..color = cs.surface);
    double y = page.top + 14;
    void line(double indent, double len, Paint paint) {
      canvas.drawRect(Rect.fromLTWH(page.left + indent, y, len, 4), paint);
      y += 9;
    }

    final slug = Paint()..color = cs.primary.withValues(alpha: 0.75);
    final action = Paint()..color = cs.onSurfaceVariant.withValues(alpha: 0.5);
    final cue = Paint()..color = cs.secondary.withValues(alpha: 0.85);
    line(14, page.width * 0.5, slug);
    y += 5;
    line(14, page.width * 0.82, action);
    line(14, page.width * 0.68, action);
    line(14, page.width * 0.76, action);
    y += 6;
    line(page.width * 0.32, page.width * 0.28, cue);
    line(page.width * 0.2, page.width * 0.52, action);
    line(page.width * 0.2, page.width * 0.38, action);
    y += 6;
    line(14, page.width * 0.78, action);
    line(14, page.width * 0.58, action);
  }

  @override
  bool shouldRepaint(_ScriptPainter old) => old.cs != cs;
}

class FoldersMock extends StatelessWidget {
  const FoldersMock({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final names = ['Raw', 'Audio', 'Images', 'Script', 'Boards', 'Exports'];
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.all(14),
      child: Wrap(spacing: 14, runSpacing: 14, children: [
        for (final n in names)
          Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder, size: 40, color: cs.primary),
            const SizedBox(height: 2),
            Text(n, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ]),
      ]),
    );
  }
}

class RendersMock extends StatelessWidget {
  const RendersMock({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = [
      ('final-cut.mp4', 1.0),
      ('scene-3.mp4', 0.62),
      ('trailer.mp4', 0.25)
    ];
    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(r.$2 >= 1 ? Icons.check_circle : Icons.timelapse,
                    size: 16, color: r.$2 >= 1 ? Colors.green : cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$1, style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 3),
                        LinearProgressIndicator(
                            value: r.$2,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2)),
                      ]),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}
