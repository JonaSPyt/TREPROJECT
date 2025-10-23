import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_manager.dart';

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
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Scanner de Código'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
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

                      // Decide what to add:
                      // - If truncated is non-empty and neither truncated nor raw exist, add truncated.
                      // - Else if raw is non-empty and not present, add raw.
                      // - Else report duplicate or invalid.
                      final hasRaw = widget.barcodeManager.containsBarcode(raw);
                      final hasTrunc = truncated.isNotEmpty && widget.barcodeManager.containsBarcode(truncated);

                      if (truncated.isNotEmpty && !hasTrunc && !hasRaw) {
                        final wasAdded = widget.barcodeManager.addBarcode(truncated);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(wasAdded
                                ? 'Código (truncado) inserido na lista: $truncated'
                                : 'Código já adicionado anteriormente'),
                            backgroundColor: wasAdded ? Colors.green : Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (raw.isNotEmpty && !hasRaw && !hasTrunc) {
                        final wasAdded = widget.barcodeManager.addBarcode(raw);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(wasAdded
                                ? 'Código inserido na lista: $raw'
                                : 'Código já adicionado anteriormente'),
                            backgroundColor: wasAdded ? Colors.green : Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Código já adicionado anteriormente ou inválido.'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
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
            color: Colors.grey[200],
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
