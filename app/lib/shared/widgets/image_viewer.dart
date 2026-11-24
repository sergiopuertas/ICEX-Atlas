import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Visor de imagen a pantalla completa con zoom (pellizcar / doble toque) y cierre
/// deslizando hacia abajo o con la X.
Future<void> showImageViewer(
  BuildContext context, {
  required String url,
  required String cacheKey,
  String? heroTag,
}) => Navigator.of(context, rootNavigator: true).push(
  PageRouteBuilder<void>(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, _, _) => _ImageViewer(url: url, cacheKey: cacheKey, heroTag: heroTag),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  ),
);

class _ImageViewer extends StatefulWidget {
  const _ImageViewer({required this.url, required this.cacheKey, this.heroTag});

  final String url;
  final String cacheKey;
  final String? heroTag;

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  final _transform = TransformationController();
  double _dragY = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  bool get _zoomed => _transform.value.getMaxScaleOnAxis() > 1.01;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget image = CachedNetworkImage(
      imageUrl: widget.url,
      cacheKey: widget.cacheKey,
      fit: BoxFit.contain,
    );
    if (widget.heroTag != null) image = Hero(tag: widget.heroTag!, child: image);
    final opacity = (1 - _dragY.abs() / 400).clamp(0.3, 1.0);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: Stack(
        children: [
          GestureDetector(
            onVerticalDragUpdate: _zoomed ? null : (d) => setState(() => _dragY += d.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    if (_dragY.abs() > 120 || (d.primaryVelocity ?? 0).abs() > 800) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _dragY = 0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(0, _dragY),
              child: InteractiveViewer(
                transformationController: _transform,
                maxScale: 4,
                child: Center(child: image),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: l.close,
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
