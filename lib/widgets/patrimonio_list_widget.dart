import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/patrimonio_manager.dart';
import '../theme/app_colors.dart';

class BarcodeListWidget extends StatelessWidget {
  final List<BarcodeItem> barcodes;
  final Function(String) onDelete;
  final Function(String, BarcodeStatus) onStatusChange;
  final void Function(BarcodeItem)? onTapItem;
  final String? Function(String code)? getPhotoPath;

  const BarcodeListWidget({
    super.key,
    required this.barcodes,
    required this.onDelete,
    required this.onStatusChange,
    this.onTapItem,
    this.getPhotoPath,
  });

  void _showStatusDialog(BuildContext context, BarcodeItem item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Selecionar Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatusOption(context, item, BarcodeStatus.found),
            _buildStatusOption(context, item, BarcodeStatus.foundNotRelated),
            _buildStatusOption(context, item, BarcodeStatus.notRegistered),
            _buildStatusOption(context, item, BarcodeStatus.damaged),
            _buildStatusOption(context, item, BarcodeStatus.notFound),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    BarcodeItem item,
    BarcodeStatus status,
  ) {
    final isSelected = item.status == status;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? status.color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            onStatusChange(item.code, status);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: status.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: status.color.withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: status.color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingWidget(int index, BarcodeItem item, String? photoPath) {
    // Se não tem foto, mostra círculo com número
    if (photoPath == null || photoPath.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              item.status.color.withOpacity(0.8),
              item.status.color,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: item.status.color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      );
    }

    // Se tem foto, decide qual ImageProvider usar
    ImageProvider imageProvider;
    if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
      imageProvider = NetworkImage(photoPath);
    } else {
      imageProvider = FileImage(File(photoPath));
    }

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: imageProvider,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[100],
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: barcodes.length,
      itemBuilder: (context, index) {
        final item = barcodes[index];
        final photoPath = getPhotoPath?.call(item.code);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTapItem == null ? null : () => onTapItem!(item),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildLeadingWidget(index, item, photoPath),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (item.status != BarcodeStatus.none)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: item.status.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.status.label,
                                style: TextStyle(
                                  color: item.status.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            Text(
                              'Sem status',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          color: AppColors.primary,
                          tooltip: 'Alterar status',
                          onPressed: () => _showStatusDialog(context, item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          color: AppColors.error,
                          tooltip: 'Remover',
                          onPressed: () => _showDeleteConfirmation(context, item),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showDeleteConfirmation(BuildContext context, BarcodeItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remover patrimônio?'),
        content: Text('Deseja remover o código ${item.code}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              onDelete(item.code);
              Navigator.pop(context);
            },
            child: const Text('Remover', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
