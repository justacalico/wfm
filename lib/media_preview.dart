import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'main.dart';
import 'platform.dart';
import 'util.dart';

/// In-app preview modal for images and playable media. On web the player is a
/// native <video>/<audio> element streaming through Range requests; on other
/// platforms the player falls back to an external-open button.
class MediaPreview extends StatelessWidget {
  final String projectId, name, path;
  const MediaPreview(
      {super.key,
      required this.projectId,
      required this.name,
      required this.path});

  static Future<void> show(BuildContext context, String pid, FileEntry e) =>
      showDialog(
          context: context,
          builder: (_) =>
              MediaPreview(projectId: pid, name: e.name, path: e.path));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = Api.i.downloadUrl(projectId, path);
    final Widget body;
    if (playableMedia(name)) {
      final audio = audioMedia(name);
      final player =
          mediaPlayer(url, audio: audio, openLabel: l10n.playInBrowser);
      body = audio
          ? SizedBox(height: 56, width: 480, child: player)
          : AspectRatio(aspectRatio: 16 / 9, child: player);
    } else {
      body = Image.network(url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.broken_image_outlined)));
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_outlined),
                    tooltip: l10n.download,
                    onPressed: () async {
                      try {
                        await openExternal(
                            Api.i.downloadUrl(projectId, path, dl: true));
                      } catch (e) {
                        if (context.mounted) snack(context, e);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ]),
                const SizedBox(height: 8),
                body,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
