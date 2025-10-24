import 'package:flutter/material.dart';

import '../utils/barcode_manager.dart';
import 'scanner_screen.dart';
import '../utils/barcode_exporter.dart';
import '../widgets/barcode_list_widget.dart';

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

  Future<void> _exportBarcodes() async {
    final barcodes = widget.barcodeManager.barcodes;

    if (barcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum código para exportar'),
        ),
      );
      return;
    }

    try {
      await BarcodeExporter.exportBarcodes(barcodes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Códigos exportados com sucesso!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final barcodes = widget.barcodeManager.barcodes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Códigos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Abrir scanner',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScannerScreen(
                    barcodeManager: widget.barcodeManager,
                  ),
                ),
              );
            },
          ),
          if (barcodes.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Exportar lista',
              onPressed: _exportBarcodes,
            ),
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
                style: TextStyle(fontSize: 16),
              ),
            )
          : BarcodeListWidget(
              barcodes: barcodes,
              onDelete: (barcode) {
                widget.barcodeManager.removeBarcode(barcode);
              },
              onStatusChange: (barcode, status) {
                widget.barcodeManager.updateBarcodeStatus(barcode, status);
              },
              onTapItem: (item) {
                final details = widget.barcodeManager.getDetails(item.code);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  builder: (context) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Detalhes do Patrimônio', style: Theme.of(context).textTheme.titleLarge),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Código: ${item.code}', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 12),
                          if (details != null) ...[
                            _detailRow(context, 'Item', details.item),
                            _detailRow(context, 'P. Antigo', details.oldCode),
                            _detailRow(context, 'Descrição', details.descricao),
                            _detailRow(context, 'Localização', details.localizacao),
                            _detailRow(context, 'Vlr. Aquisição', details.valorAquisicao),
                          ] else ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text('Sem detalhes do CSV para este código.',
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

Widget _detailRow(BuildContext context, String label, String? value) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
