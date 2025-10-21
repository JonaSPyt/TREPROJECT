import 'package:flutter/material.dart';

class BarcodeListWidget extends StatelessWidget {
  final List<String> barcodes;
  final Function(String) onDelete;

  const BarcodeListWidget({
    super.key,
    required this.barcodes,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: barcodes.length,
      itemBuilder: (context, index) {
        final barcode = barcodes[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(barcode),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDelete(barcode),
            ),
          ),
        );
      },
    );
  }
}
