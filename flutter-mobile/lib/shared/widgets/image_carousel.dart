import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:koyden_sehire/app/theme.dart';

class ImageCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final double height;
  final void Function(int index)? onImageTap;

  const ImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 280,
    this.onImageTap,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.height,
        color: AppColors.outlineVariant,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 48,
          color: AppColors.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => GestureDetector(
              onTap: widget.onImageTap == null
                  ? null
                  : () => widget.onImageTap!(i),
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[i],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (_, __) =>
                    Container(color: AppColors.outlineVariant),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.outlineVariant,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (i) {
                  final selected = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 6,
                    width: selected ? 18 : 6,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
