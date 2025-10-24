import 'package:flutter/material.dart';
import 'dart:io';
import '../utils/barcode_manager.dart';

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecionar Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(context, item, BarcodeStatus.found),
            _buildStatusOption(context, item, BarcodeStatus.foundNotRelated),
            _buildStatusOption(context, item, BarcodeStatus.notRegistered),
            _buildStatusOption(context, item, BarcodeStatus.damaged),
            _buildStatusOption(context, item, BarcodeStatus.notFound),
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
    return ListTile(
      leading: CircleAvatar(backgroundColor: status.color, radius: 12),
      title: Text(status.label),
      onTap: () {
        onStatusChange(item.code, status);
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: barcodes.length,
      itemBuilder: (context, index) {
        final item = barcodes[index];
        final photoPath = getPhotoPath?.call(item.code);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: item.status.color.withOpacity(0.1),
          child: ListTile(
            leading: photoPath != null && photoPath.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image(
                      image: FileImage(File(photoPath)),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : CircleAvatar(
                    backgroundColor: item.status.color,
                    child: Text('${index + 1}'),
                  ),
            title: Text(item.code),
            onTap: onTapItem == null ? null : () => onTapItem!(item),
            subtitle: item.status != BarcodeStatus.none
                ? Text(
                    item.status.label,
                    style: TextStyle(
                      color: item.status.color,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.label, color: Theme.of(context).colorScheme.primary),
                  tooltip: 'Alterar status',
                  onPressed: () => _showStatusDialog(context, item),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                  onPressed: () => onDelete(item.code),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
