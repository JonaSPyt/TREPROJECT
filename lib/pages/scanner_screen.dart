import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

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
                      final String code = barcodes.first.rawValue ?? '';
                      _controller.stop();
                      setState(() {
                        _barcode = code.isNotEmpty ? code : 'Valor vazio';
                        _isScanning = false;
                      });
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
