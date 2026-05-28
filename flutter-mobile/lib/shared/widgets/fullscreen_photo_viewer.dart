import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Opens a fullscreen, swipe-to-dismiss photo gallery with pinch-to-zoom.
Future<void> showFullscreenPhotoViewer(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => _FullscreenPhotoViewer(
      imageUrls: imageUrls,
      initialIndex: initialIndex,
    ),
  );
}

class _FullscreenPhotoViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenPhotoViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late final PageController _pageCtrl;
  late int _currentIndex;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity =
        (1.0 - (_dragOffset.abs() / 400)).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: GestureDetector(
        onVerticalDragUpdate: (d) {
          setState(() => _dragOffset += d.delta.dy);
        },
        onVerticalDragEnd: (_) {
          if (_dragOffset.abs() > 120) {
            Navigator.of(context).pop();
          } else {
            setState(() => _dragOffset = 0);
          }
        },
        child: Stack(
          children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PhotoViewGallery.builder(
                pageController: _pageCtrl,
                itemCount: widget.imageUrls.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.transparent),
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (ctx, i) => PhotoViewGalleryPageOptions(
                  imageProvider:
                      CachedNetworkImageProvider(widget.imageUrls[i]),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 4,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: 'photo_${widget.imageUrls[i]}',
                  ),
                ),
                loadingBuilder: (_, __) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Kapat',
              ),
            ),
            if (widget.imageUrls.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
