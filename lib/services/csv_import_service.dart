import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import '../utils/patrimonio_manager.dart';

class CsvImportService {
  /// Resultado do parsing contendo itens e metadados por código.
  static CsvParseResult parseCsvWithDetails(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    // Detecta delimitador por linha (prioridade: ; > , > tab)
    List<List<dynamic>> rows = [];
    List<String> lines = content.split(RegExp(r'\r?\n'));
    String? detectedDelimiter;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      String delimiter = ',';
      if (line.contains(';') && line.split(';').length > line.split(',').length) {
        delimiter = ';';
      } else if (line.contains('\t')) {
        delimiter = '\t';
      }
      detectedDelimiter ??= delimiter;
      final parsed = const CsvToListConverter().convert(line, fieldDelimiter: delimiter);
      if (parsed.isNotEmpty) rows.add(parsed.first);
    }
    if (rows.isEmpty) {
      return CsvParseResult(items: const [], detailsByCode: const {});
    }

    // Remove linhas totalmente em branco
    final filteredRows = rows.where((row) => row.any((cell) => cell != null && cell.toString().trim().isNotEmpty)).toList();
    if (filteredRows.isEmpty) {
      return CsvParseResult(items: const [], detailsByCode: const {});
    }

    // Aceita cabeçalhos variados
    final header = filteredRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    int idxOf(List<String> names, int fallbackIndex) {
      for (final n in names) {
        final i = header.indexWhere((h) => h == n.toLowerCase());
        if (i != -1) return i;
      }
      return fallbackIndex;
    }

    final patrimonioIndex = idxOf(['patrimônio','patrimonio','codigo','código','code'], 0);
    final itemIndex = idxOf(['item','nome','name'], 1);
    final oldIndex = idxOf(['p. antigo','antigo','old'], 2);
    final descIndex = idxOf(['descrição','descricao','description'], 3);
    final locIndex = idxOf(['localização','localizacao','location'], 4);
    final valIndex = idxOf([
      'vi. aquisição (r\$)',
      'vi. aquisicao (r\$)',
      'valor',
      'value',
      'preço',
      'preco',
      'price'
    ], 5);

    bool parseBool(dynamic v) {
      if (v == null) return false;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'x' || s == 'sim' || s == 'yes';
    }

    BarcodeStatus statusFromFlags(List row) {
      final a = row.isNotEmpty ? parseBool(row[0]) : false;
      final b = row.length > 1 ? parseBool(row[1]) : false;
      final c = row.length > 2 ? parseBool(row[2]) : false;
      final d = row.length > 3 ? parseBool(row[3]) : false;
      final e = row.length > 4 ? parseBool(row[4]) : false;
      if (a) return BarcodeStatus.found;
      if (b) return BarcodeStatus.foundNotRelated;
      if (c) return BarcodeStatus.notRegistered;
      if (d) return BarcodeStatus.damaged;
      if (e) return BarcodeStatus.notFound;
      return BarcodeStatus.none;
    }

    final List<BarcodeItem> items = [];
    final Map<String, AssetDetails> details = {};
    int linhasPuladas = 0;

    for (int i = 1; i < filteredRows.length; i++) {
      final row = filteredRows[i];
      if (row.length <= patrimonioIndex) {
        linhasPuladas++;
        print('⚠️ Linha $i pulada: row.length (${row.length}) <= patrimonioIndex ($patrimonioIndex)');
        continue;
      }
      final value = row[patrimonioIndex];
      if (value == null) {
        linhasPuladas++;
        print('⚠️ Linha $i pulada: valor nulo na coluna patrimônio');
        continue;
      }
      final code = value.toString().trim();
      if (code.isEmpty) {
        linhasPuladas++;
        print('⚠️ Linha $i pulada: código vazio');
        continue;
      }
      final status = statusFromFlags(row);
      items.add(BarcodeItem(code: code, status: status));

      String safeAt(int idx) =>
          (idx >= 0 && idx < row.length && row[idx] != null)
          ? row[idx].toString().trim()
          : '';

      details[code] = AssetDetails(
        code: code,
        item: safeAt(itemIndex),
        oldCode: safeAt(oldIndex),
        descricao: safeAt(descIndex),
        localizacao: safeAt(locIndex),
        valorAquisicao: safeAt(valIndex),
      );
    }

    print('📊 CSV Parser: ${filteredRows.length - 1} linhas de dados, $linhasPuladas puladas, ${items.length} itens válidos');
    return CsvParseResult(items: items, detailsByCode: details);
  }

  /// Retorna uma lista de BarcodeItem a partir de um arquivo CSV no formato fornecido.
  /// Regras assumidas:
  /// - Cabeçalho contém a coluna 'Patrimônio' (ou índice 6 considerando 0-based na amostra)
  /// - Linhas podem ter valores vazios; ignoramos patrimônios vazios
  /// - Valores podem ter zeros à esquerda e devem ser preservados como string
  static List<BarcodeItem> parseCsv(Uint8List bytes) {
    final content = utf8.decode(bytes, allowMalformed: true);
    // Let CsvToListConverter auto-detect line endings and quoting
    final rows = const CsvToListConverter(fieldDelimiter: ',').convert(content);

    if (rows.isEmpty) return [];

    // Encontrar o índice da coluna 'Patrimônio'
    final header = rows.first.map((e) => e.toString().trim()).toList();
    int patrimonioIndex = header.indexWhere((h) {
      final l = h.toLowerCase();
      return l == 'patrimônio' || l == 'patrimonio';
    });
    if (patrimonioIndex == -1) {
      // Fallback: com base na amostra, a coluna parece ser a 6 (0-based)
      patrimonioIndex = 6;
    }

    bool parseBool(dynamic v) {
      if (v == null) return false;
      final s = v.toString().trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'x' || s == 'sim' || s == 'yes';
    }

    BarcodeStatus statusFromFlags(List row) {
      // Consider columns A..E as indices 0..4 if present and boolean-like.
      final a = row.isNotEmpty
          ? parseBool(row[0])
          : false; // Encontrado sem nenhuma pendência
      final b = row.length > 1
          ? parseBool(row[1])
          : false; // Bens encontrados e não relacionados
      final c = row.length > 2
          ? parseBool(row[2])
          : false; // Bens permanentes sem identificação
      final d = row.length > 3 ? parseBool(row[3]) : false; // Bens danificados
      final e = row.length > 4
          ? parseBool(row[4])
          : false; // Bens não encontrados

      if (a) return BarcodeStatus.found;
      if (b) return BarcodeStatus.foundNotRelated;
      if (c) return BarcodeStatus.notRegistered;
      if (d) return BarcodeStatus.damaged;
      if (e) return BarcodeStatus.notFound;
      return BarcodeStatus.none;
    }

    final List<BarcodeItem> items = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= patrimonioIndex) continue;
      final value = row[patrimonioIndex];
      if (value == null) continue;
      final code = value.toString().trim();
      if (code.isEmpty) continue;
      final status = statusFromFlags(row);
      items.add(BarcodeItem(code: code, status: status));
    }

    return items;
  }
}

class CsvParseResult {
  final List<BarcodeItem> items;
  final Map<String, AssetDetails> detailsByCode;
  const CsvParseResult({required this.items, required this.detailsByCode});
}
