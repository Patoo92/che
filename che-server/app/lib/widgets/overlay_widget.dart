import 'package:flutter/material.dart';

class CheOverlay extends StatelessWidget {
  final String imageUrl;
  final String caption;

  const CheOverlay({
    super.key,
    required this.imageUrl,
    this.caption = '',
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(200),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                height: 400,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.broken_image,
                    size: 100,
                    color: Colors.white54,
                  );
                },
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                caption,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
