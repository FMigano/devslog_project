import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Function(int) onPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.5),
        border: Border(top: BorderSide(color: AppTheme.darkDivider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Button
          ElevatedButton.icon(
            onPressed: currentPage > 0 ? () => onPageChanged(currentPage - 1) : null,
            icon: const Icon(Icons.chevron_left, size: 20),
            label: const Text('Previous'),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentPage > 0 ? AppTheme.darkPrimary : AppTheme.darkSurfaceVariant,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.darkSurfaceVariant,
              disabledForegroundColor: AppTheme.darkTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Page Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.darkSurfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkDivider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Page',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentPage + 1}',
                  style: TextStyle(
                    color: AppTheme.darkPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  ' of ',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '$totalPages',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Next Button
          ElevatedButton.icon(
            onPressed: currentPage < totalPages - 1 ? () => onPageChanged(currentPage + 1) : null,
            label: const Text('Next'),
            icon: const Icon(Icons.chevron_right, size: 20),
            style: ElevatedButton.styleFrom(
              backgroundColor: currentPage < totalPages - 1 ? AppTheme.darkPrimary : AppTheme.darkSurfaceVariant,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.darkSurfaceVariant,
              disabledForegroundColor: AppTheme.darkTextSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}