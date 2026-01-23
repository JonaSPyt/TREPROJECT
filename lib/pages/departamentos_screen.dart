import 'package:flutter/material.dart';
import '../models/departamento.dart';
import '../services/departamento_service.dart';
import '../theme/app_colors.dart';
import '../utils/patrimonio_manager.dart';
import 'departamento_tombamentos_screen.dart';

/// Tela de listagem de departamentos estilo Google Classroom.
/// Exibe cards coloridos com informações do departamento.
class DepartamentosScreen extends StatefulWidget {
  final BarcodeManager? barcodeManager;
  
  const DepartamentosScreen({super.key, this.barcodeManager});

  @override
  State<DepartamentosScreen> createState() => _DepartamentosScreenState();
}

class _DepartamentosScreenState extends State<DepartamentosScreen> {
  final DepartamentoService _service = DepartamentoService();
  List<Departamento> _departamentos = [];
  bool _isLoading = true;
  String? _error;

  // Cores para os cards (estilo Classroom)
  static const List<Color> _cardColors = [
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFF8E24AA), // Purple
    Color(0xFFE53935), // Red
    Color(0xFFFB8C00), // Orange
    Color(0xFF00ACC1), // Cyan
    Color(0xFF3949AB), // Indigo
    Color(0xFF00897B), // Teal
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartamentos();
  }

  Future<void> _loadDepartamentos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final departamentos = await _service.listarDepartamentos();
      setState(() {
        _departamentos = departamentos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getCardColor(int index) {
    return _cardColors[index % _cardColors.length];
  }

  Future<void> _showCreateEditDialog([Departamento? departamento]) async {
    final isEditing = departamento != null;
    final codigoController = TextEditingController(text: departamento?.codigo ?? '');
    final nomeController = TextEditingController(text: departamento?.nome ?? '');
    final descricaoController = TextEditingController(text: departamento?.descricao ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Departamento>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Departamento' : 'Novo Departamento'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: codigoController,
                  decoration: const InputDecoration(
                    labelText: 'Código *',
                    hintText: 'Ex: SALA-01',
                    prefixIcon: Icon(Icons.tag),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Código é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome *',
                    hintText: 'Ex: Sala de Reuniões',
                    prefixIcon: Icon(Icons.meeting_room),
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nome é obrigatório';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    hintText: 'Descrição opcional do departamento',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newDepartamento = Departamento(
                  id: departamento?.id,
                  codigo: codigoController.text.trim().toUpperCase(),
                  nome: nomeController.text.trim(),
                  descricao: descricaoController.text.trim().isEmpty
                      ? null
                      : descricaoController.text.trim(),
                );
                Navigator.pop(context, newDepartamento);
              }
            },
            icon: Icon(isEditing ? Icons.save : Icons.add),
            label: Text(isEditing ? 'Salvar' : 'Criar'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        if (isEditing) {
          await _service.atualizarDepartamento(departamento.id!, result);
          _showSnackBar('Departamento atualizado!', Colors.green);
        } else {
          await _service.criarDepartamento(result);
          _showSnackBar('Departamento criado!', Colors.green);
        }
        _loadDepartamentos();
      } catch (e) {
        _showSnackBar('Erro: $e', Colors.red);
      }
    }
  }

  Future<void> _confirmDelete(Departamento departamento) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja excluir o departamento "${departamento.nome}"?'),
            const SizedBox(height: 8),
            if (departamento.totalTombamentos > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Este departamento possui ${departamento.totalTombamentos} tombamento(s) vinculado(s). '
                        'Primeiro desvincule os tombamentos.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
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
          if (departamento.totalTombamentos == 0)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete),
              label: const Text('Excluir'),
            ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deletarDepartamento(departamento.id!);
        _showSnackBar('Departamento excluído!', Colors.green);
        _loadDepartamentos();
      } catch (e) {
        _showSnackBar('Erro: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _openDepartamento(Departamento departamento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DepartamentoTombamentosScreen(
          departamento: departamento,
          onUpdated: _loadDepartamentos,
          barcodeManager: widget.barcodeManager,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Departamentos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDepartamentos,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Novo Departamento'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
            Text('Carregando departamentos...'),
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
              Text(
                'Erro ao carregar departamentos',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadDepartamentos,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_departamentos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder_open, size: 80, color: AppColors.textLight),
              const SizedBox(height: 16),
              Text(
                'Nenhum departamento cadastrado',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Crie um departamento para organizar seus tombamentos',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _showCreateEditDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Criar Departamento'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDepartamentos,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _departamentos.length,
        itemBuilder: (context, index) {
          final departamento = _departamentos[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DepartamentoCard(
              departamento: departamento,
              color: _getCardColor(index),
              onTap: () => _openDepartamento(departamento),
              onEdit: () => _showCreateEditDialog(departamento),
              onDelete: () => _confirmDelete(departamento),
            ),
          );
        },
      ),
    );
  }
}

/// Card estilo Google Classroom para exibir departamento
class _DepartamentoCard extends StatelessWidget {
  final Departamento departamento;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DepartamentoCard({
    required this.departamento,
    required this.color,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // Barra colorida lateral
            Container(
              width: 8,
              height: 80,
              color: color,
            ),
            // Conteúdo
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      departamento.codigo,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      departamento.nome,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            '${departamento.totalTombamentos} tombamento(s)',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Editar'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Excluir', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
