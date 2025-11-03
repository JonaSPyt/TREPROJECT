import 'package:flutter/material.dart';

import '../utils/barcode_manager.dart';
import 'scanner_screen.dart';
import '../utils/barcode_exporter.dart';
import '../widgets/barcode_list_widget.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<String?> _pickAndLinkPhoto(String code, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return null;

      final docs = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docs.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final String filename =
          '${DateTime.now().millisecondsSinceEpoch}_$code.jpg';
      final File dest = File('${photosDir.path}/$filename');
      await File(picked.path).copy(dest.path);

      await widget.barcodeManager.setPhotoForCode(code, dest.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto vinculada com sucesso.')),
        );
      }

      return dest.path;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao vincular foto: $e')));
      }
      return null;
    }
  }

  Future<void> _exportBarcodes() async {
    final barcodes = widget.barcodeManager.barcodes;

    if (barcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum código para exportar')),
      );
      return;
    }

    try {
      await BarcodeExporter.exportBarcodes(
        barcodes,
        manager: widget.barcodeManager,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Códigos exportados com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
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
                  builder: (context) =>
                      ScannerScreen(barcodeManager: widget.barcodeManager),
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
              getPhotoPath: widget.barcodeManager.getPhotoPath,
              onTapItem: (item) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        final details = widget.barcodeManager.getDetails(
                          item.code,
                        );
                        final currentPhotoPath = widget.barcodeManager
                            .getPhotoPath(item.code);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Detalhes do Patrimônio',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Código: ${item.code}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 12),
                              if (currentPhotoPath != null &&
                                  currentPhotoPath.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(currentPhotoPath),
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog(
                                            clipBehavior: Clip.antiAlias,
                                            child: InteractiveViewer(
                                              child: Image.file(
                                                File(currentPhotoPath),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.photo),
                                      label: const Text('Ver foto'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Share.shareXFiles(
                                          [XFile(currentPhotoPath)],
                                          text:
                                              'Foto do patrimônio ${item.code}',
                                        );
                                      },
                                      icon: const Icon(Icons.share),
                                      label: const Text('Compartilhar'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final path = await _pickAndLinkPhoto(
                                          item.code,
                                          ImageSource.gallery,
                                        );
                                        if (path != null) setModalState(() {});
                                      },
                                      icon: const Icon(Icons.photo_library),
                                      label: const Text('Escolher foto'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final path = await _pickAndLinkPhoto(
                                          item.code,
                                          ImageSource.camera,
                                        );
                                        if (path != null) setModalState(() {});
                                      },
                                      icon: const Icon(Icons.photo_camera),
                                      label: const Text('Tirar foto'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (details != null) ...[
                                if (details.item != null &&
                                    details.item!.isNotEmpty)
                                  _detailRow(context, 'Item', details.item),
                                _detailRow(
                                  context,
                                  'P. Antigo',
                                  details.oldCode,
                                ),
                                _detailRow(
                                  context,
                                  'Descrição',
                                  details.descricao,
                                ),
                                _detailRow(
                                  context,
                                  'Localização',
                                  details.localizacao,
                                ),
                                _detailRow(
                                  context,
                                  'Vlr. Aquisição',
                                  details.valorAquisicao,
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    'Sem detalhes do CSV para este código.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
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
