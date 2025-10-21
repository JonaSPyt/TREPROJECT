import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'barcode_manager.dart';

class BarcodeExporter {
  static Future<void> exportBarcodes(List<BarcodeItem> barcodes) async {
    if (barcodes.isEmpty) {
      throw Exception('Nenhum código para exportar');
    }

    try {
      // Criar conteúdo do arquivo
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

      // Obter diretório temporário
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/codigos_barras_$timestamp.txt';

      // Criar arquivo
      final file = File(filePath);
      await file.writeAsString(content.toString());

      // Compartilhar arquivo
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Lista de Códigos de Barras',
        text: 'Exportação de ${barcodes.length} códigos',
      );
    } catch (e) {
      throw Exception('Erro ao exportar: $e');
    }
  }
}
