import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/barcode_manager.dart';

class SyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BarcodeManager barcodeManager;
  final String projectId;
  bool _isSyncing = false;

  SyncService({required this.barcodeManager, required this.projectId});

  /// Escuta mudanças em tempo real do Firestore
  Stream<void> listenToChanges() {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('items')
        .snapshots()
        .asyncMap((snapshot) async {
          if (_isSyncing) return;

          for (var change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) continue;

            final code = data['code'] as String?;
            if (code == null || code.isEmpty) continue;

            final statusIndex = data['status'] as int? ?? 0;
            final status =
                statusIndex >= 0 && statusIndex < BarcodeStatus.values.length
                ? BarcodeStatus.values[statusIndex]
                : BarcodeStatus.none;

            switch (change.type) {
              case DocumentChangeType.added:
              case DocumentChangeType.modified:
                _isSyncing = true;
                final item = BarcodeItem(code: code, status: status);
                barcodeManager.addBarcodeItemSilent(item);
                _isSyncing = false;
                break;
              case DocumentChangeType.removed:
                _isSyncing = true;
                barcodeManager.removeBarcodeSilent(code);
                _isSyncing = false;
                break;
            }
          }
        });
  }

  /// Sincroniza um item para o Firestore
  Future<void> syncItem(BarcodeItem item) async {
    if (_isSyncing) return;
    try {
      print('Sincronizando item: ${item.code} para Firestore...');
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('items')
          .doc(item.code)
          .set({
            'code': item.code,
            'status': item.status.index,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('Item ${item.code} sincronizado com sucesso!');
    } catch (e) {
      print('Erro ao sincronizar item: $e');
    }
  }

  /// Remove um item do Firestore
  Future<void> removeItem(String code) async {
    if (_isSyncing) return;
    try {
      print('Removendo item: $code do Firestore...');
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('items')
          .doc(code)
          .delete();
      print('Item $code removido com sucesso!');
    } catch (e) {
      print('Erro ao remover item: $e');
    }
  }

  /// NOVO: Carrega todos os itens (códigos escaneados) do Firestore
  Future<void> loadItems() async {
    try {
      print('Carregando itens do Firestore...');
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('items')
          .get();

      print('Encontrados ${snapshot.docs.length} itens no Firestore');

      _isSyncing = true;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final code = data['code'] as String?;
        if (code == null || code.isEmpty) continue;

        final statusIndex = data['status'] as int? ?? 0;
        final status =
            statusIndex >= 0 && statusIndex < BarcodeStatus.values.length
            ? BarcodeStatus.values[statusIndex]
            : BarcodeStatus.none;

        final item = BarcodeItem(code: code, status: status);
        barcodeManager.addBarcodeItemSilent(item);
      }
      _isSyncing = false;

      if (snapshot.docs.isNotEmpty) {
        print('Itens carregados com sucesso!');
      }
    } catch (e) {
      print('Erro ao carregar itens: $e');
      _isSyncing = false;
    }
  }

  /// Sincroniza detalhes dos patrimônios
  Future<void> syncDetails(Map<String, AssetDetails> details) async {
    try {
      print('Sincronizando ${details.length} detalhes para Firestore...');
      final batch = _firestore.batch();

      for (final entry in details.entries) {
        final docRef = _firestore
            .collection('projects')
            .doc(projectId)
            .collection('details')
            .doc(entry.key);

        batch.set(docRef, {
          'code': entry.value.code,
          'item': entry.value.item,
          'oldCode': entry.value.oldCode,
          'descricao': entry.value.descricao,
          'localizacao': entry.value.localizacao,
          'valorAquisicao': entry.value.valorAquisicao,
        });
      }

      await batch.commit();
      print('${details.length} detalhes sincronizados com sucesso!');
    } catch (e) {
      print('Erro ao sincronizar detalhes: $e');
    }
  }

  /// Carrega detalhes do Firestore
  Future<void> loadDetails() async {
    try {
      print('Carregando detalhes do Firestore...');
      final snapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('details')
          .get();

      print('Encontrados ${snapshot.docs.length} detalhes no Firestore');

      final Map<String, AssetDetails> details = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        details[doc.id] = AssetDetails(
          code: data['code'] as String?,
          item: data['item'] as String?,
          oldCode: data['oldCode'] as String?,
          descricao: data['descricao'] as String?,
          localizacao: data['localizacao'] as String?,
          valorAquisicao: data['valorAquisicao'] as String?,
        );
      }

      if (details.isNotEmpty) {
        _isSyncing = true;
        barcodeManager.mergeDetailsSilent(details);
        _isSyncing = false;
        print('Detalhes carregados com sucesso!');
      }
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
    }
  }

  /// Limpa todos os dados do projeto
  Future<void> clearAll() async {
    try {
      print('Limpando todos os dados do Firestore...');
      final batch = _firestore.batch();

      final itemsSnapshot = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('items')
          .get();

      for (final doc in itemsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('Dados limpos com sucesso!');
    } catch (e) {
      print('Erro ao limpar dados: $e');
    }
  }
}
