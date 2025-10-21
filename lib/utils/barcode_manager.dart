import 'package:flutter/material.dart';

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

  List<BarcodeItem> get barcodes => List.unmodifiable(_barcodes);

  bool addBarcode(String barcode) {
    if (barcode.isEmpty) {
      return false;
    }

    if (_barcodes.any((item) => item.code == barcode)) {
      return false; // Código já existe
    }

    _barcodes.add(BarcodeItem(code: barcode));
    notifyListeners();
    return true; // Código adicionado com sucesso
  }

  void updateBarcodeStatus(String barcode, BarcodeStatus status) {
    final item = _barcodes.firstWhere((item) => item.code == barcode);
    item.status = status;
    notifyListeners();
  }

  void removeBarcode(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    notifyListeners();
  }

  void clearAll() {
    _barcodes.clear();
    notifyListeners();
  }
}
