import 'package:flutter/material.dart';
import '../services/departamento_service.dart';
import '../models/departamento.dart';
import '../theme/app_colors.dart';
import '../utils/patrimonio_manager.dart';

/// Tela que exibe tombamentos que não estão vinculados a nenhum departamento.
class TombamentosSemDepartamentoScreen extends StatefulWidget {
  final BarcodeManager? barcodeManager;

  const TombamentosSemDepartamentoScreen({
    super.key,
    this.barcodeManager,
  });

  @override
  State<TombamentosSemDepartamentoScreen> createState() => _TombamentosSemDepartamentoScreenState();
}

class _TombamentosSemDepartamentoScreenState extends State<TombamentosSemDepartamentoScreen> {
  final DepartamentoService _service = DepartamentoService();
  List<Map<String, dynamic>> _tombamentos = [];
  List<Departamento> _departamentos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Carrega tombamentos sem departamento e lista de departamentos
      final results = await Future.wait([
        _service.listarTombamentosSemDepartamento(),
        _service.listarDepartamentos(),
      ]);
      
      setState(() {
        _tombamentos = results[0] as List<Map<String, dynamic>>;
        _departamentos = results[1] as List<Departamento>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Vincula um tombamento a um departamento
  Future<void> _vincularAoDepartamento(Map<String, dynamic> tombamento) async {
    if (_departamentos.isEmpty) {
      _showSnackBar('Nenhum departamento disponível', Colors.orange);
      return;
    }

    final departamento = await showDialog<Departamento>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vincular ao Departamento'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Código: ${tombamento['codigo']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (tombamento['descricao']?.isNotEmpty == true)
                Text(
                  'Descrição: ${tombamento['descricao']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              const SizedBox(height: 16),
              const Text('Selecione o departamento:'),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _departamentos.length,
                  itemBuilder: (context, index) {
                    final dept = _departamentos[index];
                    return ListTile(
                      leading: const Icon(Icons.meeting_room),
                      title: Text(dept.nome),
                      subtitle: Text(dept.codigo),
                      onTap: () => Navigator.pop(context, dept),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (departamento != null) {
      try {
        _showSnackBar('Vinculando...', AppColors.primary);
        
        // Importa o tombamento no departamento selecionado
        await _service.importarTombamentos(
          departamento.id!,
          [{'codigo': tombamento['codigo'], 'descricao': tombamento['descricao'] ?? ''}],
        );

        await _loadData();
        _showSnackBar('✅ Vinculado a ${departamento.nome}!', Colors.green);
      } catch (e) {
        _showSnackBar('Erro: $e', Colors.red);
      }
    }
  }

  /// Exclui um tombamento
  Future<void> _excluirTombamento(Map<String, dynamic> tombamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir tombamento?'),
        content: Text('Deseja excluir o tombamento ${tombamento['codigo']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true && tombamento['id'] != null) {
      try {
        await _service.excluirTombamentoSemDepartamento(tombamento['id']);
        
        // Remove foto local e código do BarcodeManager se disponível
        final codigo = tombamento['codigo']?.toString();
        if (codigo != null && widget.barcodeManager != null) {
          await widget.barcodeManager!.removePhotoForCode(codigo);
          await widget.barcodeManager!.removeBarcodeSilent(codigo); // Também remove do cache local
        }
        
        await _loadData();
        _showSnackBar('✅ Tombamento excluído!', Colors.green);
      } catch (e) {
        _showSnackBar('Erro: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sem Departamento'),
            Text(
              '${_tombamentos.length} tombamentos',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF64748B),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Erro: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_tombamentos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.green.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nenhum tombamento\nsem departamento!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Todos os tombamentos estão organizados.',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tombamentos.length,
        itemBuilder: (context, index) {
          final tombamento = _tombamentos[index];
          final codigo = tombamento['codigo']?.toString() ?? '';
          final descricao = tombamento['descricao']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.folder_off,
                  color: Colors.grey,
                ),
              ),
              title: Text(
                codigo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: descricao.isNotEmpty
                  ? Text(
                      descricao,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const Text(
                      'Sem descrição',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_home_work, color: Colors.blue),
                    tooltip: 'Vincular a departamento',
                    onPressed: () => _vincularAoDepartamento(tombamento),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Excluir',
                    onPressed: () => _excluirTombamento(tombamento),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
