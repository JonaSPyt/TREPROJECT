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
  
  /// Retorna o total de códigos armazenados
  int get totalCodigos => _barcodes.length;
  
  /// Retorna o total de detalhes armazenados
  int get totalDetalhes => _detailsByCode.length;
  
  /// Retorna o total de fotos armazenadas
  int get totalFotos => _photoByCode.length;
  
  /// Obtém detalhes de um código específico (pode ser null se não existir)
  AssetDetails? getDetails(String code) => _detailsByCode[code];
  
  /// Obtém caminho da foto de um código específico (pode ser null)
  String? getPhotoPath(String code) => _photoByCode[code];

  /// Força a persistência de todos os dados imediatamente.
  /// Útil para garantir que mudanças sejam salvas antes de operações críticas.
  Future<void> forcePersist() async {
    print('💾 Forçando persistência de todos os dados...');
    await _saveToStorage();
    await _saveDetailsToStorage();
    await _savePhotosToStorage();
    print('✅ Dados persistidos: $_barcodes códigos, ${_detailsByCode.length} detalhes, ${_photoByCode.length} fotos');
  }

  /// Exibe um resumo do estado atual do cache para debug.
  void debugPrintStatus() {
    print('📊 === BarcodeManager Status ===');
    print('   Códigos: ${_barcodes.length}');
    print('   Detalhes: ${_detailsByCode.length}');
    print('   Fotos: ${_photoByCode.length}');
    if (_barcodes.isNotEmpty) {
      print('   Primeiros 5 códigos: ${_barcodes.take(5).map((e) => e.code).toList()}');
    }
    print('================================');
  }

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

  /// Busca um código cadastrado que seja sufixo do código escaneado.
  /// Exemplo: escaneado "87043854" encontra cadastrado "43854"
  /// Retorna o código cadastrado encontrado ou null.
  String? findBySuffix(String scannedCode) {
    if (scannedCode.isEmpty) return null;
    
    // Primeiro, verifica match exato
    if (containsBarcode(scannedCode)) {
      return scannedCode;
    }
    
    // Busca códigos cadastrados que sejam sufixo do escaneado
    // Prioriza o match mais longo (mais específico)
    String? bestMatch;
    int bestLength = 0;
    
    for (final item in _barcodes) {
      final cadastrado = item.code;
      // Verifica se o escaneado termina com o cadastrado
      if (scannedCode.endsWith(cadastrado) && cadastrado.length > bestLength) {
        bestMatch = cadastrado;
        bestLength = cadastrado.length;
      }
    }
    
    return bestMatch;
  }

  /// Verifica se um código escaneado corresponde a algum cadastrado.
  /// Considera match exato ou por sufixo.
  bool containsBarcodeOrSuffix(String scannedCode) {
    return findBySuffix(scannedCode) != null;
  }

  /// Adiciona um novo código à lista.
  /// Retorna true se adicionado com sucesso, false se já existir ou for vazio.
  /// Notifica listeners, persiste localmente e sincroniza com a API.
  /// Use [addBarcodeItemForBatch] para importações em lote (sem sync individual).
  bool addBarcodeItem(BarcodeItem item) {
    if (item.code.isEmpty) return false;
    if (containsBarcode(item.code)) return false;  // Evita duplicatas
    
    _barcodes.add(item);
    notifyListeners();  // Atualiza UI
    Future.microtask(() => _saveToStorage());  // Salva localmente

    // Sincroniza com a API
    if (_syncService != null) {
      Future.microtask(() => _syncService.syncItem(item));
    }

    return true;
  }

  /// Adiciona item para importação em lote.
  /// NÃO sincroniza individualmente - use mergeDetails depois para sync batch.
  bool addBarcodeItemForBatch(BarcodeItem item) {
    if (item.code.isEmpty) return false;
    if (containsBarcode(item.code)) return false;  // Evita duplicatas
    
    _barcodes.add(item);
    notifyListeners();  // Atualiza UI
    Future.microtask(() => _saveToStorage());  // Salva localmente
    // NÃO sincroniza aqui - será feito em batch via mergeDetails

    return true;
  }

  /// Versão silenciosa para adicionar código (usada quando dados vêm da API).
  /// Atualiza item existente ou adiciona novo, mas NÃO sincroniza de volta para API.
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
  /// IMPORTANTE: Agora é async e aguarda a persistência para evitar dados fantasmas.
  Future<void> removeBarcode(String barcode) async {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    // Aguarda a persistência para garantir que os dados sejam salvos
    await _saveToStorage();
    await _saveDetailsToStorage();

    // Sincroniza remoção com a API
    if (_syncService != null) {
      Future.microtask(() => _syncService.removeItem(barcode));
    }
  }

  /// Versão silenciosa para remoção (usada quando remoção vem do Firebase).
  /// NÃO sincroniza de volta para evitar loops.
  /// IMPORTANTE: Agora é async e aguarda a persistência para evitar dados fantasmas.
  Future<void> removeBarcodeSilent(String barcode) async {
    _barcodes.removeWhere((item) => item.code == barcode);
    _detailsByCode.remove(barcode);
    notifyListeners();
    // Aguarda a persistência para garantir que os dados sejam salvos
    await _saveToStorage();
    await _saveDetailsToStorage();
  }

  /// Limpa todos os dados (códigos e detalhes).
  /// Notifica listeners, persiste e sincroniza com Firebase.
  /// IMPORTANTE: Agora é async e aguarda a persistência para evitar dados fantasmas.
  Future<void> clearAll() async {
    _barcodes.clear();
    _detailsByCode.clear();
    _photoByCode.clear(); // Também limpa fotos
    notifyListeners();
    // Aguarda a persistência para garantir que os dados sejam salvos
    await _saveToStorage();
    await _saveDetailsToStorage();
    await _savePhotosToStorage();

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
