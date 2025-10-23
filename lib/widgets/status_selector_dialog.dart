import 'package:flutter/material.dart';
import '../utils/barcode_manager.dart';

/// Shows a dialog to select a status for a barcode.
/// Returns the chosen BarcodeStatus or null if the user cancels.
Future<BarcodeStatus?> pickBarcodeStatus(
  BuildContext context, {
  String title = 'Selecionar Status',
  BarcodeStatus? initial,
}) {
  final options = const <BarcodeStatus>[
    BarcodeStatus.found,
    BarcodeStatus.foundNotRelated,
    BarcodeStatus.notRegistered,
    BarcodeStatus.damaged,
    BarcodeStatus.notFound,
  ];

  return showDialog<BarcodeStatus>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map((s) => ListTile(
                    leading: CircleAvatar(backgroundColor: s.color, radius: 12),
                    title: Text(s.label),
                    trailing: initial == s
                        ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () => Navigator.pop(context, s),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );
}
