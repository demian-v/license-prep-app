import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The result page's picture: a meme from `result_memes`, or the bundled
/// success/fail picture when there is none to be had.
///
/// The space is reserved from the first frame as a plain [toneSurface] panel —
/// no spinner — and the meme fades in over it once loaded. [url] resolving to
/// null (offline, an empty collection, a missing file) or a failed image load
/// both land on [fallbackAsset], centred on the same panel.
class ResultMemePicture extends StatelessWidget {
  const ResultMemePicture({
    super.key,
    required this.url,
    required this.fallbackAsset,
    required this.toneSurface,
  });

  final Future<String?> url;
  final String fallbackAsset;
  final Color toneSurface;

  @override
  Widget build(BuildContext context) {
    final panel = ColoredBox(color: toneSurface, child: const SizedBox.expand());
    final fallback = ColoredBox(
      color: toneSurface,
      child: Center(
        child: Image.asset(
          fallbackAsset,
          width: 128,
          height: 128,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
    return FutureBuilder<String?>(
      future: url,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return panel;
        final u = snap.data;
        if (u == null) return fallback;
        return CachedNetworkImage(
          imageUrl: u,
          fit: BoxFit.cover,
          fadeInDuration: AppMotion.duration(context, AppMotion.fast),
          fadeOutDuration: Duration.zero,
          placeholder: (_, __) => panel,
          errorWidget: (_, __, ___) => fallback,
        );
      },
    );
  }
}
