import 'package:flutter/material.dart';

class ItemCard extends StatelessWidget {
  final String title;
  final String location;
  final String category;
  final String? imageUrl;
  final bool showClaimButton;
  final bool claimButtonEnabled;
  final String claimButtonText;
  final VoidCallback? onClaimPressed;

  const ItemCard({
    super.key,
    required this.title,
    required this.location,
    required this.category,
    this.imageUrl,
    this.showClaimButton = true,
    this.claimButtonEnabled = true,
    this.claimButtonText = 'Claim',
    this.onClaimPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon / placeholder image
            imageUrl != null && imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint("Error loading image in ItemCard: $error");
                        return _buildPlaceholder(context);
                      },
                    ),
                  )
                : _buildPlaceholder(context),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, 
                          size: 16, color: Theme.of(context).textTheme.bodyMedium?.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Action button
            const SizedBox(width: 8),
            Align(
              alignment: Alignment.center,
              child: showClaimButton
                  ? FilledButton.tonal(
                      onPressed: claimButtonEnabled ? onClaimPressed : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36),
                      ),
                      child: Text(claimButtonText),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'phone': return Icons.smartphone;
      case 'wallet': return Icons.account_balance_wallet;
      case 'id card': return Icons.badge;
      case 'bag': return Icons.backpack;
      case 'electronics': return Icons.laptop;
      case 'keys': return Icons.vpn_key;
      default: return Icons.help_outline;
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getCategoryIcon(category),
        color: Theme.of(context).primaryColor,
        size: 32,
      ),
    );
  }
}
