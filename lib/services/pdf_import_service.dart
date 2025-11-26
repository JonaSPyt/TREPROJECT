import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../utils/barcode_manager.dart';

/// Serviço para importação de dados a partir de arquivos PDF.
/// Extrai informações de patrimônio (tombamento) de relatórios em PDF.
class PdfImportService {
  /// Extrai texto do PDF e parseia os dados de tombamentos
  static Future<ParsedData> parsePdfWithDetails(Uint8List bytes) async {
    try {
      // Extrai texto do PDF
      final PdfDocument doc = PdfDocument(inputBytes: bytes);
      final PdfTextExtractor extractor = PdfTextExtractor(doc);
      final String fullText = extractor.extractText();
      
      print('📄 Texto extraído do PDF (${fullText.length} caracteres)');
      print('📝 Primeiros 500 caracteres:\n${fullText.substring(0, fullText.length < 500 ? fullText.length : 500)}');
      
      // Divide em linhas para processar
      final lines = fullText.split('\n');
      
      final Map<String, AssetDetails> detailsByCode = {};
      final List<String> items = [];
      
      // Variáveis para acumular informações de cada item
      String? currentCode;
      String? currentDescricao;
      String? currentLocalizacao;
      String? currentOldCode;
      String? currentValor;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // Detecta padrão de código de tombamento (números, pode ter hífen)
        // Exemplo: "824690" ou "60015601" ou "61947"
        final codeMatch = RegExp(r'^\d{4,8}$').firstMatch(line);
        
        if (codeMatch != null) {
          // Se já temos um código acumulado, salva antes
          if (currentCode != null) {
            _saveCurrentItem(
              detailsByCode,
              items,
              currentCode,
              currentDescricao,
              currentLocalizacao,
              currentOldCode,
              currentValor,
            );
          }
          
          // Inicia novo item
          currentCode = line;
          currentDescricao = null;
          currentLocalizacao = null;
          currentOldCode = null;
          currentValor = null;
          
          print('🔍 Código encontrado: $currentCode');
          continue;
        }
        
        // Se estamos processando um item, tenta identificar os campos
        if (currentCode != null) {
          // Detecta descrição (geralmente contém palavras como MICROCOMPUTADOR, SOFTWARE, etc.)
          if (line.contains('MICROCOMPUTADOR') || 
              line.contains('SOFTWARE') || 
              line.contains('NOTEBOOK') ||
              line.contains('ULTRABOOK') ||
              line.contains('TRIPE') ||
              line.contains('MODULO') ||
              line.toUpperCase().contains('DESCRICAO:') ||
              line.contains('MARCA:') ||
              line.contains('MODELO:') ||
              line.contains('SERIE:')) {
            if (currentDescricao == null) {
              currentDescricao = line;
            } else {
              currentDescricao += ' $line';
            }
            continue;
          }
          
          // Detecta localização (contém padrões como "0607-30304001" ou "SEÇÃO")
          if (line.contains('-') && 
              (line.contains('SEÇÃO') || 
               line.contains('TRE') || 
               line.contains('SEDE') ||
               RegExp(r'\d{4,6}-\d+').hasMatch(line))) {
            if (currentLocalizacao == null) {
              currentLocalizacao = line;
            } else {
              currentLocalizacao += ' $line';
            }
            continue;
          }
          
          // Detecta valor (padrão: número com vírgula ou ponto)
          final valorMatch = RegExp(r'(\d{1,3}(?:\.\d{3})*(?:,\d{2})?|\d+,\d{2}|\d+\.\d{2})').firstMatch(line);
          if (valorMatch != null && line.length < 20) {
            currentValor = valorMatch.group(0);
            print('💰 Valor encontrado para $currentCode: $currentValor');
            continue;
          }
        }
      }
      
      // Salva o último item acumulado
      if (currentCode != null) {
        _saveCurrentItem(
          detailsByCode,
          items,
          currentCode,
          currentDescricao,
          currentLocalizacao,
          currentOldCode,
          currentValor,
        );
      }
      
      print('✅ PDF parseado: ${items.length} itens encontrados');
      
      // Libera recursos do documento
      doc.dispose();
      
      return ParsedData(items: items, detailsByCode: detailsByCode);
      
    } catch (e) {
      print('❌ Erro ao parsear PDF: $e');
      rethrow;
    }
  }
  
  /// Salva o item atual nos mapas de resultado
  static void _saveCurrentItem(
    Map<String, AssetDetails> detailsByCode,
    List<String> items,
    String code,
    String? descricao,
    String? localizacao,
    String? oldCode,
    String? valor,
  ) {
    // Limpa e normaliza código (remove zeros à esquerda desnecessários)
    final cleanCode = code.replaceAll(RegExp(r'^0+'), '');
    if (cleanCode.isEmpty) return;
    
    // Adiciona à lista
    items.add(cleanCode);
    
    // Cria detalhes
    final details = AssetDetails(
      code: cleanCode,
      descricao: descricao?.trim(),
      localizacao: localizacao?.trim(),
      oldCode: oldCode?.trim(),
      valorAquisicao: valor?.trim(),
    );
    
    detailsByCode[cleanCode] = details;
    
    print('✅ Item salvo: $cleanCode');
    if (descricao != null) print('   Descrição: ${descricao.substring(0, descricao.length < 50 ? descricao.length : 50)}...');
    if (localizacao != null) print('   Localização: ${localizacao.substring(0, localizacao.length < 50 ? localizacao.length : 50)}...');
    if (valor != null) print('   Valor: $valor');
  }
}

/// Classe auxiliar para retornar dados parseados
class ParsedData {
  final List<String> items;
  final Map<String, AssetDetails> detailsByCode;
  
  ParsedData({required this.items, required this.detailsByCode});
}
