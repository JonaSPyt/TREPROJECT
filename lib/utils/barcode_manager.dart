import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

enum BarcodeStatus {
  none('Sem status', Colors.grey),
  found('Encontrado sem nenhuma pendência', Colors.green),
  foundNotRelated('Bens encontrados e não relacionados', Color(0xFFB19CD9)),
  notRegistered('Bens permanentes sem identificação', Colors.lightBlue),
  damaged('Bens danificados', Colors.orange),
  notFound('Bens não encontrados', Colors.red);

  final String label;
  final Color color;
  const BarcodeStatus(this.label, this.color);
}

class BarcodeItem {
  final String code;
  BarcodeStatus status;

  BarcodeItem({required this.code, this.status = BarcodeStatus.none});

  Map<String, dynamic> toMap() => {
        'code': code,
        'status': status.index,
      };

  factory BarcodeItem.fromMap(Map<String, dynamic> map) {
    final idx = map['status'] is int ? map['status'] as int : 0;
    final safeIdx = idx >= 0 && idx < BarcodeStatus.values.length ? idx : 0;
    return BarcodeItem(
      code: map['code']?.toString() ?? '',
      status: BarcodeStatus.values[safeIdx],
    );
  }
}

class BarcodeManager extends ChangeNotifier {
  final List<BarcodeItem> _barcodes = [];
  final Map<String, AssetDetails> _detailsByCode = {};

  List<BarcodeItem> get barcodes => List.unmodifiable(_barcodes);
  AssetDetails? getDetails(String code) => _detailsByCode[code];
  void mergeDetails(Map<String, AssetDetails> map) {
    _detailsByCode.addAll(map);
    // Not persisting details for now; they come from the CSV import session.
    notifyListeners();
  }

  /// Returns true if a barcode with [code] already exists in the manager.
  bool containsBarcode(String code) {
    return _barcodes.any((item) => item.code == code);
  }

  /// Adds a [BarcodeItem] preserving its status. Returns true if it was
  /// added, false if a barcode with the same code already exists.
  bool addBarcodeItem(BarcodeItem item) {
    if (item.code.isEmpty) return false;
    if (containsBarcode(item.code)) return false;
    _barcodes.add(item);
    notifyListeners();
  // persist asynchronously
  Future.microtask(() => _saveToStorage());
    return true;
  }

  bool addBarcode(String barcode) {
    if (barcode.isEmpty) {
      return false;
    }

    if (_barcodes.any((item) => item.code == barcode)) {
      return false; // Código já existe
    }

    _barcodes.add(BarcodeItem(code: barcode));
    notifyListeners();
  // persist asynchronously
  Future.microtask(() => _saveToStorage());
    return true; // Código adicionado com sucesso
  }

  void updateBarcodeStatus(String barcode, BarcodeStatus status) {
    final item = _barcodes.firstWhere((item) => item.code == barcode);
    item.status = status;
    notifyListeners();
  // persist asynchronously
  Future.microtask(() => _saveToStorage());
  }

  void removeBarcode(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    notifyListeners();
  // persist asynchronously
  Future.microtask(() => _saveToStorage());
  }

  void clearAll() {
    _barcodes.clear();
    notifyListeners();
    // persist asynchronously
    Future.microtask(() => _saveToStorage());
  }

  // Storage helpers
  Future<File> _getStorageFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/items.json');
  }

  /// Load saved items into the manager (replaces current in-memory list)
  Future<void> loadFromStorage() async {
    try {
      final file = await _getStorageFile();
      // Migrate old storage file if present
      final dir = await getApplicationDocumentsDirectory();
      final oldFile = File('${dir.path}/third_items.json');
      if (!await file.exists() && await oldFile.exists()) {
        try {
          await oldFile.rename(file.path);
        } catch (_) {
          // If rename fails, fall through to try reading old file directly
        }
      }
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        _barcodes.clear();
        _barcodes.addAll(decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => BarcodeItem.fromMap(m)));
        notifyListeners();
      }
    } catch (_) {
      // ignore read/parse errors
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final file = await _getStorageFile();
      final jsonList = _barcodes.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (_) {
      // ignore write errors
    }
  }
}

/// Additional metadata parsed from CSV for a given patrimony code.
class AssetDetails {
  final String code; // Patrimônio
  final String? oldCode; // P. Antigo
  final String? descricao;
  final String? localizacao;
  final String? valorAquisicao;
  final String? item; // Item id/sequence if present

  AssetDetails({
    required this.code,
    this.oldCode,
    this.descricao,
    this.localizacao,
    this.valorAquisicao,
    this.item,
  });
}
