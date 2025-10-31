import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'barcode_manager.dart';

class BarcodeExporter {
  /// Exporta uma pasta compactada (.zip) contendo:
  /// - Um arquivo TXT com a listagem atual (como já é hoje)
  /// - Todas as fotos anexadas, com o nome do arquivo sendo o código do patrimônio
  ///
  /// Observação: Por limitação de compartilhamento em Android/iOS, é gerado
  /// um arquivo .zip com a pasta e seus conteúdos para facilitar o envio.
  static Future<void> exportBarcodes(
    List<BarcodeItem> barcodes, {
    required BarcodeManager manager,
  }) async {
    if (barcodes.isEmpty) {
      throw Exception('Nenhum código para exportar');
    }

    try {
      // Criar conteúdo do arquivo TXT
      final StringBuffer content = StringBuffer();
      content.writeln('Lista de Códigos de Barras');
      content.writeln('Data: ${DateTime.now().toString().split('.')[0]}');
      content.writeln('Total: ${barcodes.length} códigos\n');
      content.writeln('=' * 50);
      content.writeln();

      for (int i = 0; i < barcodes.length; i++) {
        final item = barcodes[i];
        content.writeln('${i + 1}. ${item.code}');
        content.writeln('   Status: ${item.status.label}');
        content.writeln();
      }

      // Obter diretório temporário e criar pasta da exportação
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportFolderName = 'exportacao_$timestamp';
      final exportDir = Directory('${tempDir.path}/$exportFolderName');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // 1) Criar o TXT dentro da pasta
      final txtFile = File('${exportDir.path}/codigos_barras.txt');
      await txtFile.writeAsString(content.toString());

      // 2) Copiar todas as fotos anexadas, renomeando para o código
      for (final item in barcodes) {
        final originalPath = manager.getPhotoPath(item.code);
        if (originalPath == null || originalPath.isEmpty) continue;
        final src = File(originalPath);
        if (!await src.exists()) continue;

        // Preservar extensão original se possível
        final ext = _safeExtension(originalPath);
        final sanitized = _sanitizeFilename(item.code);
        final destPath = '${exportDir.path}/$sanitized$ext';
        await src.copy(destPath);
      }

      // 3) Compactar a pasta para .zip (para ser facilmente compartilhável)
      final zipPath = '${tempDir.path}/$exportFolderName.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addDirectory(exportDir, includeDirName: true);
      encoder.close();

      // 4) Compartilhar o .zip
      await Share.shareXFiles(
        [XFile(zipPath)],
        subject: 'Exportação de Códigos de Barras',
        text: 'Exportação de ${barcodes.length} códigos com fotos anexas',
      );
    } catch (e) {
      throw Exception('Erro ao exportar: $e');
    }
  }

  static String _sanitizeFilename(String input) {
    // Remove/replace caracteres inválidos para nome de arquivo
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return sanitized.isEmpty ? 'sem_nome' : sanitized;
  }

  static String _safeExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot != -1 && dot < name.length - 1) {
      final ext = name.substring(dot);
      // limitar a extensões comuns
      if (ext.length <= 8) return ext;
    }
    return '.jpg';
  }
}
