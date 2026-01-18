import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareButton extends StatelessWidget {
  final String title;
  final String? url;

  const ShareButton({
    super.key,
    required this.title,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () {
        final shareText = url != null 
            ? '$title\n\n$url'
            : title;
        Share.share(shareText);
      },
    );
  }
}
