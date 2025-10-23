import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_manager.dart';
import '../widgets/status_selector_dialog.dart';

class ScannerScreen extends StatefulWidget {
  final BarcodeManager barcodeManager;

  const ScannerScreen({super.key, required this.barcodeManager});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  String _barcode = 'Nenhum código lido ainda';
  bool _isScanning = true;
  final MobileScannerController _controller = MobileScannerController();

  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _controller.start();
      } else {
        _controller.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner de Código'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) async {
                    if (!_isScanning) return;
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isNotEmpty) {
                      final String raw = barcodes.first.rawValue ?? '';
                      // Prepare truncated version (strip first 3 chars and leading zeros)
                      String truncated = raw.length > 3 ? raw.substring(3) : '';
                      truncated = truncated.replaceFirst(RegExp(r'^0+'), '');

                      _controller.stop();
                      // Always display the raw value to the user
                      setState(() {
                        _barcode = raw.isNotEmpty ? raw : 'Valor vazio';
                        _isScanning = false;
                      });

                      // Determine presence of raw and truncated
                      final hasRaw = raw.isNotEmpty && widget.barcodeManager.containsBarcode(raw);
                      final hasTrunc = truncated.isNotEmpty && widget.barcodeManager.containsBarcode(truncated);

                      // Decide code to add (new) or existing code (duplicate)
                      String? codeToAdd;
                      String? existingCode;
                      if (truncated.isNotEmpty && !hasTrunc && !hasRaw) {
                        codeToAdd = truncated;
                      } else if (raw.isNotEmpty && !hasRaw && !hasTrunc) {
                        codeToAdd = raw;
                      } else if (hasRaw || hasTrunc) {
                        existingCode = hasRaw ? raw : truncated;
                      }

                      if (codeToAdd != null) {
                        // Ask user to select a status before adding
                        final chosen = await pickBarcodeStatus(context, title: 'Selecione o status do código');
                        if (chosen != null) {
                          final wasAdded = widget.barcodeManager.addBarcodeItem(
                            BarcodeItem(code: codeToAdd, status: chosen),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  wasAdded
                                      ? 'Código inserido: $codeToAdd (status: ${chosen.label})'
                                      : 'Código já adicionado anteriormente',
                                ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } else if (existingCode != null) {
                        // Ask whether to keep or change status
                        final action = await showDialog<String>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Código já existente'),
                            content: const Text('Deseja manter o status atual ou alterar?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'keep'),
                                child: const Text('Manter'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, 'change'),
                                child: const Text('Alterar'),
                              ),
                            ],
                          ),
                        );

                        if (action == 'change') {
                          final chosen = await pickBarcodeStatus(context, title: 'Selecione o novo status');
                          if (chosen != null) {
                            widget.barcodeManager.updateBarcodeStatus(existingCode, chosen);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Status atualizado para: ${chosen.label}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          }
                        } else if (action == 'keep') {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Mantido status atual.'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        }
                      } else {
                        // invalid empty read
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Leitura inválida.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                if (!_isScanning)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        _controller.start();
                        setState(() {
                          _isScanning = true;
                        });
                      },
                      child: const Text('Retomar'),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Último código lido:'),
                const SizedBox(height: 8),
                Text(_barcode, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _toggleScanning,
                      child: Text(_isScanning ? 'Parar' : 'Iniciar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _barcode = 'Nenhum código lido ainda';
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
