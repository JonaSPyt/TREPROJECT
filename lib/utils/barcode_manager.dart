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

  Map<String, dynamic> toMap() => {'code': code, 'status': status.index};

  factory BarcodeItem.fromMap(Map<String, dynamic> map) {
    final statusIndex = map['status'] as int? ?? 0;
    final status = statusIndex >= 0 && statusIndex < BarcodeStatus.values.length
        ? BarcodeStatus.values[statusIndex]
        : BarcodeStatus.none;
    return BarcodeItem(code: map['code'] as String, status: status);
  }
}

class BarcodeManager extends ChangeNotifier {
  final List<BarcodeItem> _barcodes = [];
  final Map<String, AssetDetails> _detailsByCode = {};
  final Map<String, String> _photoByCode = {};

  // Referência ao SyncService
  dynamic _syncService;

  void setSyncService(dynamic syncService) {
    _syncService = syncService;
  }

  List<BarcodeItem> get barcodes => List.unmodifiable(_barcodes);
  AssetDetails? getDetails(String code) => _detailsByCode[code];
  String? getPhotoPath(String code) => _photoByCode[code];

  Future<void> setPhotoForCode(String code, String path) async {
    _photoByCode[code] = path;
    notifyListeners();
    await _savePhotosToStorage();
  }

  Future<void> removePhotoForCode(String code) async {
    final path = _photoByCode.remove(code);
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
    notifyListeners();
    await _savePhotosToStorage();
  }

  void mergeDetails(Map<String, AssetDetails> map) {
    _detailsByCode.addAll(map);
    notifyListeners();
    Future.microtask(() => _saveDetailsToStorage());

    // Sincroniza detalhes com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncDetails(map));
    }
  }

  void mergeDetailsSilent(Map<String, AssetDetails> map) {
    _detailsByCode.addAll(map);
    notifyListeners();
    Future.microtask(() => _saveDetailsToStorage());
  }

  bool containsBarcode(String code) {
    return _barcodes.any((item) => item.code == code);
  }

  bool addBarcodeItem(BarcodeItem item) {
    if (item.code.isEmpty) return false;
    if (containsBarcode(item.code)) return false;
    _barcodes.add(item);
    notifyListeners();
    Future.microtask(() => _saveToStorage());

    // Sincroniza com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncItem(item));
    }

    return true;
  }

  void addBarcodeItemSilent(BarcodeItem item) {
    if (item.code.isEmpty) return;
    final index = _barcodes.indexWhere((i) => i.code == item.code);
    if (index != -1) {
      _barcodes[index] = item;
    } else {
      _barcodes.add(item);
    }
    notifyListeners();
    Future.microtask(() => _saveToStorage());
  }

  void updateBarcodeStatus(String barcode, BarcodeStatus status) {
    final item = _barcodes.firstWhere((item) => item.code == barcode);
    item.status = status;
    notifyListeners();
    Future.microtask(() => _saveToStorage());

    // Sincroniza com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncItem(item));
    }
  }

  void removeBarcode(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    Future.microtask(() => _saveToStorage());
    Future.microtask(() => _saveDetailsToStorage());

    // Sincroniza remoção com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.removeItem(barcode));
    }
  }

  void removeBarcodeSilent(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    Future.microtask(() => _saveToStorage());
    Future.microtask(() => _saveDetailsToStorage());
  }

  void clearAll() {
    _barcodes.clear();
    _detailsByCode.clear();
    notifyListeners();
    Future.microtask(() => _saveToStorage());
    Future.microtask(() => _saveDetailsToStorage());

    // Sincroniza limpeza com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.clearAll());
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/barcodes.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        _barcodes.clear();
        _barcodes.addAll(jsonList.map((e) => BarcodeItem.fromMap(e)));
        notifyListeners();
      }
    } catch (e) {
      print('Erro ao carregar: $e');
    }

    await _loadDetailsFromStorage();
    await _loadPhotosFromStorage();
  }

  Future<void> _saveToStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/barcodes.json');
      final jsonList = _barcodes.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Erro ao salvar: $e');
    }
  }

  Future<void> _saveDetailsToStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/details.json');
      final map = _detailsByCode.map((k, v) => MapEntry(k, v.toMap()));
      await file.writeAsString(jsonEncode(map));
    } catch (e) {
      print('Erro ao salvar detalhes: $e');
    }
  }

  Future<void> _loadDetailsFromStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/details.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> map = jsonDecode(content);
        _detailsByCode.clear();
        map.forEach((k, v) {
          _detailsByCode[k] = AssetDetails.fromMap(v);
        });
      }
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
    }
  }

  Future<void> _savePhotosToStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/photos.json');
      await file.writeAsString(jsonEncode(_photoByCode));
    } catch (e) {
      print('Erro ao salvar fotos: $e');
    }
  }

  Future<void> _loadPhotosFromStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/photos.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> map = jsonDecode(content);
        _photoByCode.clear();
        map.forEach((k, v) {
          if (v is String) _photoByCode[k] = v;
        });
      }
    } catch (e) {
      print('Erro ao carregar fotos: $e');
    }
  }
}

class AssetDetails {
  final String? code;
  final String? item;
  final String? oldCode;
  final String? descricao;
  final String? localizacao;
  final String? valorAquisicao;

  AssetDetails({
    this.code,
    this.item,
    this.oldCode,
    this.descricao,
    this.localizacao,
    this.valorAquisicao,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'item': item,
    'oldCode': oldCode,
    'descricao': descricao,
    'localizacao': localizacao,
    'valorAquisicao': valorAquisicao,
  };

  factory AssetDetails.fromMap(Map<String, dynamic> map) {
    return AssetDetails(
      code: map['code'] as String?,
      item: map['item'] as String?,
      oldCode: map['oldCode'] as String?,
      descricao: map['descricao'] as String?,
      localizacao: map['localizacao'] as String?,
      valorAquisicao: map['valorAquisicao'] as String?,
    );
  }
}
