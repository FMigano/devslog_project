import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';

class ShareButton extends StatelessWidget {
  final String title;
  final String? url;
  final String? text;

  const ShareButton({
    super.key,
    required this.title,
    this.url,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () {
        _showShareDialog(context);
      },
      tooltip: 'Share',
    );
  }

  void _showShareDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share Post', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.primaryColor),
                title: const Text('Copy Link'),
                onTap: () {
                  final shareText = url ?? text ?? title;
                  Share.share(shareText);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share, color: AppTheme.successColor),
                title: const Text('Share via...'),
                onTap: () {
                  final shareText = '$title\n${url ?? text ?? ""}';
                  Share.share(shareText);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
