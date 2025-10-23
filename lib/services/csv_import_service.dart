import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import '../utils/barcode_manager.dart';

class CsvImportService {
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
      final a = row.isNotEmpty ? parseBool(row[0]) : false; // Encontrado sem nenhuma pendência
      final b = row.length > 1 ? parseBool(row[1]) : false; // Bens encontrados e não relacionados
      final c = row.length > 2 ? parseBool(row[2]) : false; // Bens permanentes sem identificação
      final d = row.length > 3 ? parseBool(row[3]) : false; // Bens danificados
      final e = row.length > 4 ? parseBool(row[4]) : false; // Bens não encontrados

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
