import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/departamento.dart';
import '../services/departamento_service.dart';
import '../services/csv_import_service.dart';
import '../services/pdf_import_service.dart';
import '../theme/app_colors.dart';
import '../utils/patrimonio_manager.dart';

/// Tela que exibe os tombamentos de um departamento específico.
/// Permite importar, visualizar e atualizar status dos tombamentos.
class DepartamentoTombamentosScreen extends StatefulWidget {
  final Departamento departamento;
  final VoidCallback? onUpdated;
  final BarcodeManager? barcodeManager; // Para sincronização local

  const DepartamentoTombamentosScreen({
    super.key,
    required this.departamento,
    this.onUpdated,
    this.barcodeManager,
  });

  @override
  State<DepartamentoTombamentosScreen> createState() => _DepartamentoTombamentosScreenState();
}

class _DepartamentoTombamentosScreenState extends State<DepartamentoTombamentosScreen> {
  final DepartamentoService _service = DepartamentoService();
  List<Map<String, dynamic>> _tombamentos = [];
  bool _isLoading = true;
  String? _error;
  
  // Filtro de status
  int? _statusFilter;
  
  // Pesquisa
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTombamentos();
  }

  Future<void> _loadTombamentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tombamentos = await _service.listarTombamentos(widget.departamento.id!);
      setState(() {
        _tombamentos = tombamentos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Importa tombamentos de arquivo PDF ou CSV
  Future<void> _importarArquivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;

      if (bytes == null) {
        _showSnackBar('Erro ao ler arquivo', Colors.red);
        return;
      }

      // Mostra loading
      _showSnackBar('Importando arquivo...', AppColors.primary, duration: 30);

      // Parseia o arquivo
      final extension = file.extension?.toLowerCase();
      late final dynamic parsed;
      
      if (extension == 'pdf') {
        parsed = await PdfImportService.parsePdfWithDetails(bytes);
      } else {
        parsed = CsvImportService.parseCsvWithDetails(bytes);
      }

      // Converte para o formato esperado pela API
      final tombamentos = <Map<String, dynamic>>[];
      final codigosUnicos = <String>{};
      int duplicados = 0;
      int vazios = 0;
      
      // Função para converter valor brasileiro (1.234,56) para formato numérico (1234.56)
      String converterValorParaNumerico(String valor) {
        if (valor.isEmpty) return '';
        // Remove espaços e caracteres não numéricos exceto . e ,
        String limpo = valor.replaceAll(RegExp(r'[^\d.,]'), '').trim();
        if (limpo.isEmpty) return '';
        
        // Conta ocorrências de . e ,
        final pontos = '.'.allMatches(limpo).length;
        final virgulas = ','.allMatches(limpo).length;
        
        // Se tem vírgula, assume formato brasileiro (1.234,56)
        if (virgulas > 0) {
          // Remove pontos (separador de milhar) e troca vírgula por ponto decimal
          limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
        } else if (pontos > 1) {
          // Múltiplos pontos sem vírgula (ex: 4.750.00) - remove todos exceto o último
          final partes = limpo.split('.');
          final ultimaParte = partes.removeLast();
          limpo = '${partes.join('')}.$ultimaParte';
        }
        // Se tem apenas um ponto, assume que já é formato internacional
        
        return limpo;
      }
      
      for (final item in parsed.items) {
        final codigo = item.code?.toString().trim() ?? '';
        if (codigo.isEmpty) {
          vazios++;
          continue;
        }
        if (codigosUnicos.contains(codigo)) {
          duplicados++;
          continue;
        }
        codigosUnicos.add(codigo);
        final details = parsed.detailsByCode[item.code];
        final valorOriginal = details?.valorAquisicao ?? '';
        final valorConvertido = converterValorParaNumerico(valorOriginal);
        
        tombamentos.add({
          'codigo': codigo,
          'descricao': details?.descricao ?? '',
          'localizacao': details?.localizacao ?? '',
          'valor': valorConvertido,
          'status': 0, // Status 0 = não verificado
        });
      }
      
      print('📊 CSV: ${parsed.items.length} linhas, $vazios vazios, $duplicados duplicados, ${tombamentos.length} únicos para enviar');

      if (tombamentos.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showSnackBar('Arquivo não contém tombamentos válidos', Colors.orange);
        return;
      }

      // Envia para a API
      final response = await _service.importarTombamentosBatch(
        widget.departamento.id!,
        tombamentos,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final criados = response['criados'] ?? 0;
      final atualizados = response['atualizados'] ?? 0;
      final ignorados = response['ignorados'] ?? 0;
      _showSnackBar(
        'Importado: $criados novos, $atualizados atualizados, $ignorados ignorados',
        Colors.green,
      );
      
      // Força atualização da lista
      await _loadTombamentos();
      widget.onUpdated?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Erro ao importar: $e', Colors.red);
    }
  }

  /// Mostra dialog para atualizar status do tombamento
  Future<void> _showStatusDialog(Map<String, dynamic> tombamento) async {
    final currentStatus = tombamento['status'] as int? ?? 0;
    
    final newStatus = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Status: ${tombamento['codigo']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusOption(0, 'Não verificado', currentStatus),
            _buildStatusOption(1, 'Encontrado', currentStatus),
            _buildStatusOption(2, 'Encontrado, não relacionado', currentStatus),
            _buildStatusOption(3, 'Sem identificação', currentStatus),
            _buildStatusOption(4, 'Danificado', currentStatus),
            _buildStatusOption(5, 'Não encontrado', currentStatus),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (newStatus != null && newStatus != currentStatus) {
      try {
        await _service.atualizarStatusTombamento(tombamento['id'], newStatus);
        _showSnackBar('Status atualizado!', Colors.green);
        _loadTombamentos();
      } catch (e) {
        _showSnackBar('Erro ao atualizar: $e', Colors.red);
      }
    }
  }

  Widget _buildStatusOption(int status, String label, int currentStatus) {
    final isSelected = status == currentStatus;
    final statusData = _getStatusData(status);
    return ListTile(
      leading: Text(statusData.emoji, style: const TextStyle(fontSize: 20)),
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
      selected: isSelected,
      onTap: () => Navigator.pop(context, status),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  /// Remove tombamento
  Future<void> _removerTombamento(Map<String, dynamic> tombamento) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Remoção'),
        content: Text('Deseja remover o tombamento "${tombamento['codigo']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.removerTombamento(tombamento['id']);
        
        // Remove também do BarcodeManager local se disponível
        final codigo = tombamento['codigo'] as String?;
        if (codigo != null && widget.barcodeManager != null) {
          await widget.barcodeManager!.removePhotoForCode(codigo); // Remove foto local
          widget.barcodeManager!.removeBarcode(codigo);
        }
        
        _showSnackBar('Tombamento removido!', Colors.green);
        _loadTombamentos();
        widget.onUpdated?.call();
      } catch (e) {
        _showSnackBar('Erro ao remover: $e', Colors.red);
      }
    }
  }

  /// Mostra dialog para editar tombamento (descrição, localização, foto, etc.)
  Future<void> _showEditDialog(Map<String, dynamic> tombamento) async {
    final descricaoController = TextEditingController(text: tombamento['descricao'] ?? '');
    final localizacaoController = TextEditingController(text: tombamento['localizacao'] ?? '');
    String? novaFotoPath;
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editar: ${tombamento['codigo']}',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Foto atual ou nova
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (pickedFile != null) {
                        setDialogState(() {
                          novaFotoPath = pickedFile.path;
                        });
                      }
                    },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: novaFotoPath != null
                          ? Image.file(
                              File(novaFotoPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 150,
                            )
                          : tombamento['foto'] != null && tombamento['foto'].toString().isNotEmpty
                              ? Image.network(
                                  tombamento['foto'].toString().startsWith('http')
                                      ? tombamento['foto']
                                      : 'http://192.168.200.91:3000${tombamento['foto']}',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 150,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, size: 40, color: AppColors.textSecondary),
                                        SizedBox(height: 8),
                                        Text('Toque para adicionar foto', style: TextStyle(color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 40, color: AppColors.textSecondary),
                                      SizedBox(height: 8),
                                      Text('Toque para adicionar foto', style: TextStyle(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Campo Descrição
                  TextField(
                    controller: descricaoController,
                    decoration: InputDecoration(
                      labelText: 'Descrição',
                      hintText: 'Digite a descrição do item',
                      prefixIcon: const Icon(Icons.description),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  
                  // Campo Localização
                  TextField(
                    controller: localizacaoController,
                    decoration: InputDecoration(
                      labelText: 'Localização',
                      hintText: 'Onde o item está localizado',
                      prefixIcon: const Icon(Icons.location_on),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Botão para alterar status
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, {'openStatus': true});
                    },
                    icon: const Icon(Icons.flag),
                    label: const Text('Alterar Status'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context, {
                  'descricao': descricaoController.text.trim(),
                  'localizacao': localizacaoController.text.trim(),
                  'foto': novaFotoPath,
                });
              },
              icon: const Icon(Icons.save),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    descricaoController.dispose();
    localizacaoController.dispose();

    if (result == null) return;

    // Se pediu para abrir dialog de status
    if (result['openStatus'] == true) {
      await _showStatusDialog(tombamento);
      return;
    }

    // Salvar alterações
    try {
      _showSnackBar('Salvando alterações...', AppColors.primary);
      
      // Prepara dados para enviar
      final updateData = <String, dynamic>{
        'descricao': result['descricao'],
        'localizacao': result['localizacao'],
      };

      // Se tem nova foto, envia primeiro
      if (result['foto'] != null) {
        await _service.uploadFotoTombamento(
          tombamento['id'],
          File(result['foto']),
        );
      }

      // Atualiza outros dados
      await _service.atualizarTombamento(tombamento['id'], updateData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Tombamento atualizado!', Colors.green);
      
      await _loadTombamentos();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Erro ao salvar: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor, {int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: duration),
      ),
    );
  }

  /// Exibe diálogo de confirmação para excluir todos os tombamentos do departamento
  Future<void> _confirmarDeletarTodosTombamentos() async {
    if (_tombamentos.isEmpty) {
      _showSnackBar('Não há tombamentos para excluir', Colors.orange);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Excluir todos?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Você está prestes a excluir TODOS os ${_tombamentos.length} tombamentos do departamento "${widget.departamento.nome}".',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta ação não pode ser desfeita!',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir Todos'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _deletarTodosTombamentos();
    }
  }

  /// Exclui todos os tombamentos do departamento
  Future<void> _deletarTodosTombamentos() async {
    try {
      // Esconde snackbar anterior se existir
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      _showSnackBar('Excluindo tombamentos...', AppColors.primary, duration: 2);

      // Coleta os códigos antes de excluir (para limpar dados locais)
      final codigos = _tombamentos.map((t) => t['codigo']?.toString()).whereType<String>().toList();
      print('🗑️ Preparando exclusão de ${codigos.length} tombamentos...');
      print('🗑️ BarcodeManager disponível: ${widget.barcodeManager != null}');
      print('🗑️ Total no BarcodeManager antes: ${widget.barcodeManager?.barcodes.length ?? 0}');

      // Usa o endpoint batch para excluir todos de uma vez
      final result = await _service.excluirTodosTombamentos(widget.departamento.id!);
      
      final excluidos = result['excluidos'] ?? 0;

      // Remove dados locais dos tombamentos excluídos (fotos e códigos)
      if (widget.barcodeManager != null) {
        for (final codigo in codigos) {
          await widget.barcodeManager!.removePhotoForCode(codigo);
          widget.barcodeManager!.removeBarcodeSilent(codigo); // Remove do BarcodeManager local
        }
        print('🗑️ ${codigos.length} tombamentos removidos localmente');
        print('🗑️ Total no BarcodeManager depois: ${widget.barcodeManager!.barcodes.length}');
      } else {
        print('⚠️ BarcodeManager é null - não foi possível limpar dados locais!');
      }

      // Recarrega a lista
      await _loadTombamentos();
      
      // Notifica atualização
      widget.onUpdated?.call();

      // Mostra resultado
      _showSnackBar('✅ $excluidos tombamentos excluídos!', Colors.green);
    } catch (e) {
      _showSnackBar('Erro ao excluir: $e', Colors.red);
    }
  }

  /// Exibe diálogo para adicionar tombamento manualmente
  Future<void> _adicionarTombamentoManual() async {
    final codigoController = TextEditingController();
    final descricaoController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.green),
            SizedBox(width: 12),
            Text('Novo Tombamento'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codigoController,
              decoration: const InputDecoration(
                labelText: 'Código *',
                hintText: 'Ex: 12345',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Mesa de escritório',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final codigo = codigoController.text.trim();
              if (codigo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Código é obrigatório'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, {
                'codigo': codigo,
                'descricao': descricaoController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _criarTombamento(result['codigo']!, result['descricao'] ?? '');
    }
  }

  /// Cria um novo tombamento no departamento
  Future<void> _criarTombamento(String codigo, String descricao) async {
    try {
      _showSnackBar('Criando tombamento...', AppColors.primary, duration: 2);

      await _service.importarTombamentos(
        widget.departamento.id!,
        [{'codigo': codigo, 'descricao': descricao, 'status': 0}],
      );

      await _loadTombamentos();
      widget.onUpdated?.call();

      _showSnackBar('✅ Tombamento $codigo criado!', Colors.green);
    } catch (e) {
      _showSnackBar('Erro ao criar: $e', Colors.red);
    }
  }

  List<Map<String, dynamic>> get _filteredTombamentos {
    var result = _tombamentos;
    
    // Filtro por status
    if (_statusFilter != null) {
      result = result.where((t) => (t['status'] ?? 0) == _statusFilter).toList();
    }
    
    // Filtro por pesquisa
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((t) {
        final codigo = (t['codigo'] ?? '').toString().toLowerCase();
        final descricao = (t['descricao'] ?? '').toString().toLowerCase();
        return codigo.contains(query) || descricao.contains(query);
      }).toList();
    }
    
    return result;
  }

  int _countByStatus(int status) {
    return _tombamentos.where((t) => (t['status'] ?? 0) == status).length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Pesquisar código ou descrição...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.departamento.nome),
                  Text(
                    '${_tombamentos.length} tombamentos',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          // Botão de Pesquisa
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                  _searchController.clear();
                }
              });
            },
            tooltip: _isSearching ? 'Fechar pesquisa' : 'Pesquisar',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTombamentos,
            tooltip: 'Atualizar',
          ),
          PopupMenuButton<int?>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onSelected: (value) => setState(() => _statusFilter = value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: null,
                child: Text('Todos (${_tombamentos.length})'),
              ),
              const PopupMenuDivider(),
              _buildFilterOption(0, 'Não verificado'),
              _buildFilterOption(1, 'Encontrado'),
              _buildFilterOption(2, 'Não relacionado'),
              _buildFilterOption(3, 'Sem identificação'),
              _buildFilterOption(4, 'Danificado'),
              _buildFilterOption(5, 'Não encontrado'),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Mais opções',
            onSelected: (value) {
              if (value == 'delete_all') {
                _confirmarDeletarTodosTombamentos();
              } else if (value == 'add_manual') {
                _adicionarTombamentoManual();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'add_manual',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Adicionar tombamento'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Excluir todos', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'import',
        onPressed: _importarArquivo,
        icon: const Icon(Icons.upload_file),
        label: const Text('Importar'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  PopupMenuItem<int?> _buildFilterOption(int status, String label) {
    final count = _countByStatus(status);
    final data = _getStatusData(status);
    return PopupMenuItem(
      value: status,
      child: Row(
        children: [
          Text(data.emoji),
          const SizedBox(width: 8),
          Text('$label ($count)'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Carregando tombamentos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text('Erro ao carregar', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadTombamentos,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_tombamentos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 80, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                'Nenhum tombamento',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Importe um arquivo PDF ou CSV',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _importarArquivo,
                icon: const Icon(Icons.upload_file),
                label: const Text('Importar Arquivo'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredTombamentos;
    
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text('Nenhum com este status', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _statusFilter = null),
              child: const Text('Limpar filtro'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTombamentos,
      child: Column(
        children: [
          _buildStatusSummary(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final tombamento = filtered[index];
                return _TombamentoCard(
                  tombamento: tombamento,
                  onStatusTap: () => _showStatusDialog(tombamento),
                  onDelete: () => _removerTombamento(tombamento),
                  onEdit: () => _showEditDialog(tombamento),
                  barcodeManager: widget.barcodeManager,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSummary() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatusChip(0, 'Pendente'),
            _buildStatusChip(1, 'Encontrado'),
            _buildStatusChip(2, 'Não relac.'),
            _buildStatusChip(3, 'Sem ident.'),
            _buildStatusChip(4, 'Danificado'),
            _buildStatusChip(5, 'Não enc.'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(int status, String label) {
    final count = _countByStatus(status);
    final isSelected = _statusFilter == status;
    final data = _getStatusData(status);
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('${data.emoji} $count'),
        selected: isSelected,
        onSelected: (_) => setState(() => _statusFilter = isSelected ? null : status),
        tooltip: label,
      ),
    );
  }

  ({Color color, String emoji, String label}) _getStatusData(int status) {
    switch (status) {
      case 1: return (color: Colors.green, emoji: '✅', label: 'Encontrado');
      case 2: return (color: Colors.amber.shade700, emoji: '🟡', label: 'Não relacionado');
      case 3: return (color: Colors.orange, emoji: '🟠', label: 'Sem identificação');
      case 4: return (color: Colors.red, emoji: '🔴', label: 'Danificado');
      case 5: return (color: Colors.blueGrey, emoji: '❌', label: 'Não encontrado');
      default: return (color: Colors.blueGrey.shade400, emoji: '⚪', label: 'Não verificado');
    }
  }
}

class _TombamentoCard extends StatelessWidget {
  final Map<String, dynamic> tombamento;
  final VoidCallback onStatusTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final BarcodeManager? barcodeManager;

  const _TombamentoCard({
    required this.tombamento,
    required this.onStatusTap,
    required this.onDelete,
    required this.onEdit,
    this.barcodeManager,
  });

  /// Mostra menu de opções ao clicar no card
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                tombamento['codigo'] ?? 'Tombamento',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (tombamento['descricao'] != null && tombamento['descricao'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    tombamento['descricao'],
                    style: const TextStyle(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.edit, color: AppColors.primary),
                title: const Text('Editar'),
                subtitle: const Text('Alterar descrição, localização ou foto'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text('Alterar Status'),
                subtitle: const Text('Marcar como encontrado, não encontrado, etc.'),
                onTap: () {
                  Navigator.pop(context);
                  onStatusTap();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remover', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Excluir este tombamento'),
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Obtém a URL/path da foto (prioriza local, depois API)
  String? _getPhotoPath() {
    final codigo = tombamento['codigo'] as String?;
    
    // 1. Primeiro verifica foto local no BarcodeManager
    if (codigo != null && barcodeManager != null) {
      final localPath = barcodeManager!.getPhotoPath(codigo);
      if (localPath != null && localPath.isNotEmpty) {
        return localPath;
      }
    }
    
    // 2. Se não tem local, usa a foto da API
    final foto = tombamento['foto'] as String?;
    final updatedAt = tombamento['updated_at'] as String?;
    if (foto == null || foto.isEmpty) return null;
    
    // Se já é URL completa, retorna direto (com cache busting)
    if (foto.startsWith('http://') || foto.startsWith('https://')) {
      final cacheBuster = updatedAt ?? DateTime.now().millisecondsSinceEpoch.toString();
      return foto.contains('?') ? '$foto&t=$cacheBuster' : '$foto?t=$cacheBuster';
    }
    
    // Adiciona a baseUrl (para paths como /uploads/... ou caminhos relativos)
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://192.168.200.91:3000';
    final cacheBuster = updatedAt ?? DateTime.now().millisecondsSinceEpoch.toString();
    return '$baseUrl$foto?t=$cacheBuster';
  }

  Widget _buildPhotoWidget(String photoPath, Color statusColor, String emoji) {
    // Verifica se é URL (http/https) ou arquivo local
    final isNetwork = photoPath.startsWith('http://') || photoPath.startsWith('https://');
    
    if (isNetwork) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          photoPath,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: statusColor,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            );
          },
        ),
      );
    } else {
      // Arquivo local
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(photoPath),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = tombamento['status'] as int? ?? 0;
    final statusData = _getStatusData(status);
    final photoPath = _getPhotoPath();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showOptionsMenu(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Foto ou ícone de status
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: statusData.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusData.color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: photoPath != null
                    ? _buildPhotoWidget(photoPath, statusData.color, statusData.emoji)
                    : Center(child: Text(statusData.emoji, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tombamento['codigo'] ?? 'Sem código',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                    if (tombamento['descricao'] != null && tombamento['descricao'].toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tombamento['descricao'],
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusData.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusData.label,
                          style: TextStyle(color: statusData.color, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        if (photoPath != null) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.photo_camera, size: 14, color: AppColors.textLight),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'status') onStatusTap();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20, color: AppColors.primary), SizedBox(width: 8), Text('Editar')])),
                  const PopupMenuItem(value: 'status', child: Row(children: [Icon(Icons.flag, size: 20), SizedBox(width: 8), Text('Alterar Status')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('Remover', style: TextStyle(color: Colors.red))])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ({Color color, String emoji, String label}) _getStatusData(int status) {
    switch (status) {
      case 1: return (color: Colors.green, emoji: '✅', label: 'Encontrado');
      case 2: return (color: Colors.amber.shade700, emoji: '🟡', label: 'Não relacionado');
      case 3: return (color: Colors.orange, emoji: '🟠', label: 'Sem identificação');
      case 4: return (color: Colors.red, emoji: '🔴', label: 'Danificado');
      case 5: return (color: Colors.blueGrey, emoji: '❌', label: 'Não encontrado');
      default: return (color: Colors.blueGrey.shade400, emoji: '⚪', label: 'Não verificado');
    }
  }
}
