import 'package:flutter/material.dart';
import '../utils/barcode_manager.dart';

class BlankScreen extends StatefulWidget {
  final BarcodeManager barcodeManager;

  const BlankScreen({super.key, required this.barcodeManager});

  @override
  State<BlankScreen> createState() => _BlankScreenState();
}

class _BlankScreenState extends State<BlankScreen> {
  @override
  void initState() {
    super.initState();
    widget.barcodeManager.addListener(_onBarcodeListChanged);
  }

  @override
  void dispose() {
    widget.barcodeManager.removeListener(_onBarcodeListChanged);
    super.dispose();
  }

  void _onBarcodeListChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final barcodes = widget.barcodeManager.barcodes;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Lista de Códigos'),
        actions: [
          if (barcodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Limpar lista'),
                    content: const Text('Deseja remover todos os códigos?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          widget.barcodeManager.clearAll();
                          Navigator.pop(context);
                        },
                        child: const Text('Limpar'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: barcodes.isEmpty
          ? const Center(
              child: Text(
                'Nenhum código escaneado ainda',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
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
                      onPressed: () {
                        widget.barcodeManager.removeBarcode(barcode);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
