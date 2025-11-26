import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Enumeração que define os possíveis status de um patrimônio.
/// Cada status possui um label descritivo e uma cor associada para
/// facilitar a identificação visual na interface.
enum BarcodeStatus {
  none('Sem status', Colors.grey),
  found('Encontrado sem nenhuma pendência', Colors.green),
  foundNotRelated('Bens encontrados e não relacionados', Color(0xFFB19CD9)),
  notRegistered('Bens permanentes sem identificação', Colors.lightBlue),
  damaged('Bens danificados', Colors.orange),
  notFound('Bens não encontrados', Colors.red);

  final String label;  // Descrição do status
  final Color color;   // Cor para representação visual
  const BarcodeStatus(this.label, this.color);
}

/// Classe que representa um item de código de barras/patrimônio.
/// Contém o código identificador e o status atual do item.
class BarcodeItem {
  final String code;          // Código do patrimônio
  BarcodeStatus status;       // Status atual (pode ser alterado)

  BarcodeItem({required this.code, this.status = BarcodeStatus.none});

  /// Converte o item para Map para serialização JSON
  Map<String, dynamic> toMap() => {'code': code, 'status': status.index};

  /// Cria um item a partir de um Map (desserialização JSON)
  factory BarcodeItem.fromMap(Map<String, dynamic> map) {
    final statusIndex = map['status'] as int? ?? 0;
    // Validação: garante que o índice está dentro dos valores válidos
    final status = statusIndex >= 0 && statusIndex < BarcodeStatus.values.length
        ? BarcodeStatus.values[statusIndex]
        : BarcodeStatus.none;
    return BarcodeItem(code: map['code'] as String, status: status);
  }
}

/// Gerenciador central de estado para códigos de barras e patrimônios.
/// Implementa ChangeNotifier para notificar a UI sobre mudanças de estado.
/// 
/// Responsabilidades:
/// - Gerenciar lista de códigos escaneados
/// - Armazenar detalhes adicionais (CSV)
/// - Gerenciar caminhos de fotos
/// - Persistir dados localmente (JSON)
/// - Sincronizar com Firebase Firestore
class BarcodeManager extends ChangeNotifier {
  // Lista interna de códigos escaneados
  final List<BarcodeItem> _barcodes = [];
  
  // Mapa de detalhes adicionais por código (dados do CSV)
  final Map<String, AssetDetails> _detailsByCode = {};
  
  // Mapa de caminhos de fotos por código
  final Map<String, String> _photoByCode = {};

  // Referência ao serviço de sincronização Firebase (tipo dinâmico para evitar dependência circular)
  dynamic _syncService;

  /// Define o serviço de sincronização após a inicialização
  void setSyncService(dynamic syncService) {
    _syncService = syncService;
  }

  /// Retorna lista imutável de códigos para leitura externa
  List<BarcodeItem> get barcodes => List.unmodifiable(_barcodes);
  
  /// Obtém detalhes de um código específico (pode ser null se não existir)
  AssetDetails? getDetails(String code) => _detailsByCode[code];
  
  /// Obtém caminho da foto de um código específico (pode ser null)
  String? getPhotoPath(String code) => _photoByCode[code];

  /// Vincula uma foto a um código específico.
  /// Salva no mapa interno, notifica listeners e persiste no storage.
  Future<void> setPhotoForCode(String code, String path) async {
    if (path.isEmpty) {
      print('⚠️  Tentando salvar path vazio para código $code');
      return;
    }
    print('💾 Salvando foto: $code -> $path');
    _photoByCode[code] = path;
    notifyListeners();  // Atualiza a UI
    await _savePhotosToStorage();  // Persiste no arquivo JSON
  }

  /// Remove a foto associada a um código.
  /// Remove do mapa, deleta o arquivo físico (se não for URL) e persiste as mudanças.
  Future<void> removePhotoForCode(String code) async {
    final path = _photoByCode.remove(code);
    if (path != null) {
      // Só tenta deletar arquivo se não for uma URL HTTP
      if (!path.startsWith('http://') && !path.startsWith('https://')) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();  // Deleta arquivo físico local
        }
      }
    }
    notifyListeners();
    await _savePhotosToStorage();
  }

  /// Mescla detalhes adicionais (normalmente vindos de importação CSV).
  /// Adiciona ao mapa existente, notifica listeners, persiste e sincroniza com Firebase.
  void mergeDetails(Map<String, AssetDetails> map) {
    _detailsByCode.addAll(map);
    notifyListeners();
    Future.microtask(() => _saveDetailsToStorage());

    // Sincroniza detalhes com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncDetails(map));
    }
  }

  /// Versão silenciosa (sem sincronizar Firebase) para evitar loops.
  /// Usada quando os dados vêm do Firebase para evitar sync bidirecional.
  void mergeDetailsSilent(Map<String, AssetDetails> map) {
    _detailsByCode.addAll(map);
    notifyListeners();
    Future.microtask(() => _saveDetailsToStorage());
  }

  /// Verifica se um código já existe na lista
  bool containsBarcode(String code) {
    return _barcodes.any((item) => item.code == code);
  }

  /// Adiciona um novo código à lista.
  /// Retorna true se adicionado com sucesso, false se já existir ou for vazio.
  /// Notifica listeners, persiste localmente e sincroniza com Firebase.
  bool addBarcodeItem(BarcodeItem item) {
    if (item.code.isEmpty) return false;
    if (containsBarcode(item.code)) return false;  // Evita duplicatas
    
    _barcodes.add(item);
    notifyListeners();  // Atualiza UI
    Future.microtask(() => _saveToStorage());  // Salva localmente

    // Sincroniza com Firestore
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncItem(item));
    }

    return true;
  }

  /// Versão silenciosa para adicionar código (usada quando dados vêm do Firebase).
  /// Atualiza item existente ou adiciona novo, mas NÃO sincroniza de volta para Firebase.
  void addBarcodeItemSilent(BarcodeItem item) {
    if (item.code.isEmpty) return;
    final index = _barcodes.indexWhere((i) => i.code == item.code);
    if (index != -1) {
      _barcodes[index] = item;  // Atualiza existente
    } else {
      _barcodes.add(item);  // Adiciona novo
    }
    notifyListeners();
    Future.microtask(() => _saveToStorage());
  }

  /// Atualiza o status de um código específico.
  /// Notifica listeners, persiste e sincroniza com Firebase.
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

  /// Remove um código da lista.
  /// Remove tanto o código quanto seus detalhes associados.
  /// Notifica listeners, persiste e sincroniza remoção com a API.
  void removeBarcode(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    Future.microtask(() => _saveToStorage());
    Future.microtask(() => _saveDetailsToStorage());

    // Sincroniza remoção com a API
    if (_syncService != null) {
      Future.microtask(() => _syncService.removeItem(barcode));
    }
  }

  /// Versão silenciosa para remoção (usada quando remoção vem do Firebase).
  /// NÃO sincroniza de volta para evitar loops.
  void removeBarcodeSilent(String barcode) {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    Future.microtask(() => _saveToStorage());
    Future.microtask(() => _saveDetailsToStorage());
  }

  /// Limpa todos os dados (códigos e detalhes).
  /// Notifica listeners, persiste e sincroniza com Firebase.
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

  /// Carrega todos os dados do armazenamento local (JSON files).
  /// Chamado na inicialização do app.
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

    // Carrega também detalhes e fotos
    await _loadDetailsFromStorage();
    await _loadPhotosFromStorage();
  }

  /// Salva a lista de códigos em arquivo JSON local.
  /// Arquivo: <DocumentDirectory>/barcodes.json
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

  /// Salva o mapa de detalhes em arquivo JSON local.
  /// Arquivo: <DocumentDirectory>/details.json
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

  /// Carrega detalhes do arquivo JSON local.
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

  /// Salva o mapa de fotos (código -> caminho) em arquivo JSON.
  /// Arquivo: <DocumentDirectory>/photos.json
  Future<void> _savePhotosToStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/photos.json');
      await file.writeAsString(jsonEncode(_photoByCode));
    } catch (e) {
      print('Erro ao salvar fotos: $e');
    }
  }

  /// Carrega o mapa de fotos do arquivo JSON local.
  Future<void> _loadPhotosFromStorage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/photos.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> map = jsonDecode(content);
        _photoByCode.clear();
        map.forEach((k, v) {
          if (v is String && v.isNotEmpty) {
            _photoByCode[k] = v;  // Validação de tipo e não vazio
            print('📂 Carregada foto: $k -> $v');
          }
        });
        print('✅ Total de fotos carregadas: ${_photoByCode.length}');
      }
    } catch (e) {
      print('Erro ao carregar fotos: $e');
    }
  }
}

/// Classe que armazena detalhes adicionais de um patrimônio.
/// Normalmente preenchida através de importação CSV.
class AssetDetails {
  final String? code;            // Código do patrimônio
  final String? item;            // Número do item
  final String? oldCode;         // Código antigo (se houver)
  final String? descricao;       // Descrição do bem
  final String? localizacao;     // Localização física
  final String? valorAquisicao;  // Valor de aquisição

  AssetDetails({
    this.code,
    this.item,
    this.oldCode,
    this.descricao,
    this.localizacao,
    this.valorAquisicao,
  });

  /// Converte para Map para serialização JSON
  Map<String, dynamic> toMap() => {
    'code': code,
    'item': item,
    'oldCode': oldCode,
    'descricao': descricao,
    'localizacao': localizacao,
    'valorAquisicao': valorAquisicao,
  };

  /// Cria instância a partir de Map (desserialização JSON)
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
