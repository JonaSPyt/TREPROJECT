import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'barcode_manager.dart';

/// Classe utilitária para exportação de códigos de barras e fotos.
/// Gera arquivo ZIP contendo lista formatada e todas as fotos vinculadas.
class BarcodeExporter {
  /// Exporta códigos e fotos em formato ZIP para compartilhamento.
  /// 
  /// Estrutura do ZIP gerado:
  /// ```
  /// exportacao_<timestamp>.zip/
  /// ├── codigos_barras.txt      # Lista formatada com status
  /// ├── 12345678.jpg            # Foto do patrimônio 1
  /// ├── 87654321.jpg            # Foto do patrimônio 2
  /// └── ...
  /// ```
  /// 
  /// Formato do arquivo TXT:
  /// ```
  /// Lista de Códigos de Barras
  /// Data: 2025-11-06 14:30:00
  /// Total: 25 códigos
  /// ==================================================
  /// 
  /// 1. 12345678
  ///    Status: Encontrado sem nenhuma pendência
  /// 
  /// 2. 87654321
  ///    Status: Bens não encontrados
  /// ...
  /// ```
  /// 
  /// Parâmetros:
  /// - barcodes: Lista de códigos a exportar
  /// - manager: BarcodeManager para acessar fotos vinculadas
  /// 
  /// Throws:
  /// - Exception se lista vazia ou erro durante exportação
  static Future<void> exportBarcodes(
    List<BarcodeItem> barcodes, {
    required BarcodeManager manager,
  }) async {
    if (barcodes.isEmpty) {
      throw Exception('Nenhum código para exportar');
    }

    try {
      // === ETAPA 1: GERAR CONTEÚDO DO ARQUIVO TXT ===
      final StringBuffer content = StringBuffer();
      
      // Cabeçalho
      content.writeln('Lista de Códigos de Barras');
      content.writeln('Data: ${DateTime.now().toString().split('.')[0]}');
      content.writeln('Total: ${barcodes.length} códigos\n');
      content.writeln('=' * 50);
      content.writeln();

      // Lista numerada de códigos com status
      for (int i = 0; i < barcodes.length; i++) {
        final item = barcodes[i];
        // Escreve código e status
        content.writeln('${i + 1}. ${item.code}');
        content.writeln('   Status: ${item.status.label}');

        // Se houver descrição nos detalhes importados via CSV, exporta também
        final details = manager.getDetails(item.code);
        if (details != null && details.descricao != null && details.descricao!.trim().isNotEmpty) {
          content.writeln('   Descrição: ${details.descricao}');
        }

        content.writeln();
      }

      // === ETAPA 2: CRIAR DIRETÓRIO TEMPORÁRIO ===
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportFolderName = 'exportacao_$timestamp';
      final exportDir = Directory('${tempDir.path}/$exportFolderName');
      
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // === ETAPA 3: SALVAR ARQUIVO TXT ===
      final txtFile = File('${exportDir.path}/codigos_barras.txt');
      await txtFile.writeAsString(content.toString());

      // === ETAPA 4: COPIAR FOTOS COM NOME = CÓDIGO ===
      for (final item in barcodes) {
        final originalPath = manager.getPhotoPath(item.code);
        
        // Pula se não tem foto vinculada
        if (originalPath == null || originalPath.isEmpty) continue;
        
        final src = File(originalPath);
        if (!await src.exists()) continue;  // Foto deletada manualmente

        // Nome do arquivo = código do patrimônio (sanitizado)
        final ext = _safeExtension(originalPath);  // Preserva extensão original
        final sanitized = _sanitizeFilename(item.code);  // Remove caracteres inválidos
        final destPath = '${exportDir.path}/$sanitized$ext';
        
        await src.copy(destPath);
      }

      // === ETAPA 5: COMPACTAR EM ZIP ===
      // Necessário porque Android/iOS não permitem compartilhar pastas diretamente
      final zipPath = '${tempDir.path}/$exportFolderName.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      encoder.addDirectory(exportDir, includeDirName: true);
      encoder.close();

      // === ETAPA 6: COMPARTILHAR VIA SHARE API ===
      await Share.shareXFiles(
        [XFile(zipPath)],
        subject: 'Exportação de Códigos de Barras',
        text: 'Exportação de ${barcodes.length} códigos com fotos anexas',
      );
      
    } catch (e) {
      throw Exception('Erro ao exportar: $e');
    }
  }

  /// Remove caracteres inválidos de nomes de arquivo.
  /// 
  /// Substitui caracteres proibidos em sistemas de arquivo por underscore.
  /// Caracteres removidos: \ / : * ? " < > |
  /// Espaços também são convertidos em underscore.
  static String _sanitizeFilename(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')  // Remove caracteres inválidos
        .replaceAll(RegExp(r'\s+'), '_')           // Substitui espaços por _
        .trim();
    return sanitized.isEmpty ? 'sem_nome' : sanitized;
  }

  /// Extrai extensão do arquivo de forma segura.
  /// 
  /// Retorna .jpg por padrão se não conseguir determinar a extensão.
  /// Limita extensão a 8 caracteres para evitar nomes muito longos.
  static String _safeExtension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    
    if (dot != -1 && dot < name.length - 1) {
      final ext = name.substring(dot);
      // Limitar a extensões comuns (máximo 8 chars)
      if (ext.length <= 8) return ext;
    }
    
    // Padrão: assume JPG
    return '.jpg';
  }
}
