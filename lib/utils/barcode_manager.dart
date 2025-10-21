import 'package:flutter/material.dart';

class BarcodeManager extends ChangeNotifier {
  final List<String> _barcodes = [];

  List<String> get barcodes => List.unmodifiable(_barcodes);

  bool addBarcode(String barcode) {
    if (barcode.isEmpty) {
      return false;
    }

    if (_barcodes.contains(barcode)) {
      return false; // Código já existe
    }

    _barcodes.add(barcode);
    notifyListeners();
    return true; // Código adicionado com sucesso
  }

  void removeBarcode(String barcode) {
    _barcodes.remove(barcode);
    notifyListeners();
  }

  void clearAll() {
    _barcodes.clear();
    notifyListeners();
  }
}
