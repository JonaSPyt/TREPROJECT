import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_manager.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
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
  final MobileScannerController _controller = MobileScannerController(
    returnImage: true,
  );

  Future<bool?> _confirmFrameOk(Uint8List bytes, String code) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Esta foto está ok?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                width: 320,
                height: 240,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Código: $code',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCaptureImageForCode(List<int> bytes, String code) async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docs.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final String filename = '${DateTime.now().millisecondsSinceEpoch}_$code.jpg';
      final File dest = File('${photosDir.path}/$filename');
      await dest.writeAsBytes(bytes, flush: true);

      await widget.barcodeManager.setPhotoForCode(code, dest.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto vinculada com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Falha ao salvar foto: $e')),
        );
      }
    }
  }

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
                      final Uint8List? frameBytes = capture.image;
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

                          // For NEW codes: confirm current scanner frame before linking as photo
                          final existingPhoto = widget.barcodeManager.getPhotoPath(codeToAdd);
                          if ((existingPhoto == null || existingPhoto.isEmpty) && frameBytes != null) {
                            final ok = await _confirmFrameOk(frameBytes, codeToAdd);
                            if (ok == true) {
                              await _saveCaptureImageForCode(frameBytes, codeToAdd);
                            }
                          }
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

                        // If existing code has no photo, confirm the current frame before linking
                        final existingPhoto = widget.barcodeManager.getPhotoPath(existingCode);
                        if ((existingPhoto == null || existingPhoto.isEmpty) && frameBytes != null) {
                          final ok = await _confirmFrameOk(frameBytes, existingCode);
                          if (ok == true) {
                            await _saveCaptureImageForCode(frameBytes, existingCode);
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
