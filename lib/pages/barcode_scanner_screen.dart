import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/patrimonio_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/status_selector_dialog.dart';
import '../services/api_service.dart';
import '../services/departamento_service.dart';
import '../models/departamento.dart';

/// Tela de escaneamento de códigos de barras.
/// Implementa sistema de verificação tripla para garantir leituras intencionais.
class ScannerScreen extends StatefulWidget {
  final BarcodeManager barcodeManager;
  final ApiService? apiService;
  final bool singleScanMode; // Modo de escaneamento único - retorna o código
  final Function(String)? onCodeScanned; // Callback quando código é escaneado no modo single

  const ScannerScreen({
    super.key, 
    required this.barcodeManager,
    this.apiService,
    this.singleScanMode = false,
    this.onCodeScanned,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // Texto exibido na UI mostrando o código lido e progresso
  String _barcode = 'Nenhum código lido ainda';
  
  // Controla se o scanner está ativo ou pausado
  bool _isScanning = true;
  
  // Controlador da câmera para escaneamento
  final MobileScannerController _controller = MobileScannerController();
  
  // === SISTEMA DE VERIFICAÇÃO TRIPLA ===
  // Evita leituras acidentais exigindo 3 leituras consecutivas do mesmo código
  
  String? _lastScannedCode;    // Último código detectado
  int _consecutiveScans = 0;   // Contador de leituras consecutivas (0-3)
  DateTime? _lastScanTime;     // Timestamp da última leitura válida
  
  // Constantes do sistema de verificação
  static const _scanInterval = Duration(milliseconds: 200);  // Intervalo mínimo entre leituras
  static const _requiredScans = 3;  // Número de leituras necessárias para confirmar

  /// Seleciona e vincula uma foto a um código de patrimônio.
  /// 
  /// Parâmetros:
  /// - code: Código do patrimônio
  /// - source: Origem da foto (câmera ou galeria)
  /// 
  /// Processo:
  /// 1. Abre ImagePicker para seleção/captura
  /// 2. Comprime imagem (max 1600px, qualidade 85%)
  /// 3. Copia para diretório de fotos do app
  /// 4. Vincula caminho ao código no BarcodeManager
  Future<void> _pickAndLinkPhoto(String code, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,        // Limita largura para economizar espaço
        imageQuality: 85,      // Compressão para reduzir tamanho do arquivo
      );
      if (picked == null) return;  // Usuário cancelou

      // Prepara diretório de fotos
      final docs = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${docs.path}/photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      
      // Gera nome único com timestamp
      final String filename = '${DateTime.now().millisecondsSinceEpoch}_$code.jpg';
      final File dest = File('${photosDir.path}/$filename');
      await File(picked.path).copy(dest.path);

      // Salva foto localmente primeiro
      await widget.barcodeManager.setPhotoForCode(code, dest.path);

      // Tenta fazer upload para API se conectado
      if (widget.apiService != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📤 Enviando foto para API...')),
          );
        }
        
        final fotoUrl = await widget.apiService!.uploadPhoto(code, dest.path);
        
        if (mounted) {
          if (fotoUrl != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Foto vinculada e enviada para API!'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Foto salva localmente, mas falhou upload para API'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Foto vinculada localmente')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao vincular foto: $e')),
        );
      }
    }
  }

  /// Exibe dialog perguntando se usuário deseja adicionar foto.
  /// 
  /// Opções:
  /// - Pular: Não adiciona foto
  /// - Galeria: Seleciona foto existente
  /// - Câmera: Captura nova foto
  Future<void> _askToAddPhoto(String code) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar foto?'),
        content: const Text('Deseja adicionar uma foto para este código?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Pular'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'gallery'),
            child: const Text('Galeria'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'camera'),
            child: const Text('Câmera'),
          ),
        ],
      ),
    );

    // Processa escolha do usuário
    if (choice == 'gallery') {
      await _pickAndLinkPhoto(code, ImageSource.gallery);
    } else if (choice == 'camera') {
      await _pickAndLinkPhoto(code, ImageSource.camera);
    }
  }

  /// Alterna entre estado de escaneamento ativo e pausado.
  /// Quando pausado/retomado, reseta os contadores de verificação.
  void _toggleScanning() {
    setState(() {
      _isScanning = !_isScanning;
      if (_isScanning) {
        _controller.start();
      } else {
        _controller.stop();
      }
      // Resetar contadores ao pausar/retomar para evitar comportamento inconsistente
      _lastScannedCode = null;
      _consecutiveScans = 0;
      _lastScanTime = null;
    });
  }

  /// Retorna emoji correspondente ao status do patrimônio
  String _getStatusEmoji(BarcodeStatus status) {
    switch (status) {
      case BarcodeStatus.none:
        return '⚪';
      case BarcodeStatus.found:
        return '✅';
      case BarcodeStatus.foundNotRelated:
        return '🟣';
      case BarcodeStatus.notRegistered:
        return '🔵';
      case BarcodeStatus.damaged:
        return '🟠';
      case BarcodeStatus.notFound:
        return '❌';
    }
  }

  /// Constrói uma linha de informação para exibição no dialog
  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[400],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Exibe dialog para adicionar ou editar descrição do patrimônio.
  /// Se descricaoAtual for fornecida, pré-preenche o campo.
  /// Retorna a descrição digitada ou null se usuário pulou/cancelou.
  Future<String?> _showDescriptionDialog(String code, {String? descricaoAtual}) async {
    final controller = TextEditingController(text: descricaoAtual ?? '');
    final isEditing = descricaoAtual != null && descricaoAtual.isNotEmpty;
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Descrição' : 'Adicionar Descrição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Código: $code'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: isEditing 
                    ? 'Edite a descrição se necessário'
                    : 'Digite uma descrição para este item',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEditing ? 'Cancelar' : 'Pular'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(isEditing ? 'Atualizar' : 'Salvar'),
          ),
        ],
      ),
    );
  }

  /// Exibe dialog para selecionar um departamento ou pular.
  /// Retorna o departamento selecionado ou null se o usuário pulou.
  Future<Departamento?> _showDepartamentoDialog(String code) async {
    final departamentoService = DepartamentoService();
    
    try {
      final departamentos = await departamentoService.listarDepartamentos();
      
      if (!mounted) return null;
      
      if (departamentos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nenhum departamento cadastrado'),
            duration: Duration(seconds: 2),
          ),
        );
        return null;
      }
      
      return showDialog<Departamento>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enviar para Departamento?'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Código: $code'),
                const SizedBox(height: 16),
                const Text(
                  'Selecione o departamento:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: departamentos.length,
                    itemBuilder: (context, index) {
                      final dept = departamentos[index];
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
              child: const Text('Pular'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar departamentos: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return null;
    }
  }

  /// Adiciona o código a um departamento na API
  Future<void> _adicionarAoDepartamento(String code, Departamento departamento) async {
    final departamentoService = DepartamentoService();
    
    try {
      await departamentoService.importarTombamentos(
        departamento.id!,
        [{'codigo': code, 'descricao': widget.barcodeManager.getDetails(code)?.descricao ?? ''}],
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código $code adicionado ao departamento ${departamento.nome}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar ao departamento: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Processa um código após confirmação (3 leituras consecutivas).
  /// 
  /// Fluxo:
  /// 1. Normaliza o código (remove prefixo e zeros à esquerda)
  /// 2. Verifica se código já existe (local ou backend, por sufixo)
  /// 3. Se novo: pede status, descrição e foto
  /// 4. Se existente: mostra informações atuais
  Future<void> _processConfirmedCode(String raw) async {
    // Busca inteligente: verifica se o código escaneado corresponde a algum cadastrado
    // Isso resolve o problema de códigos de barras com prefixos extras
    // Ex: escaneado "87043854" encontra cadastrado "43854"
    
    // 1. Primeiro busca no BarcodeManager local
    String? matchedCode = widget.barcodeManager.findBySuffix(raw);
    Map<String, dynamic>? tombamentoBackend;
    
    debugPrint('🔍 [Scanner] Código escaneado: $raw');
    debugPrint('🔍 [Scanner] Match local: $matchedCode');
    
    // 2. Se não encontrou localmente, busca no backend por sufixo
    if (matchedCode == null) {
      try {
        final deptService = DepartamentoService();
        final result = await deptService.buscarTombamentoPorCodigoOuSufixo(raw);
        debugPrint('🔍 [Scanner] Resultado backend: $result');
        if (result != null) {
          matchedCode = result['codigo'] as String?;
          debugPrint('🔍 [Scanner] Código encontrado no backend: $matchedCode');
          tombamentoBackend = result['tombamento'] as Map<String, dynamic>?;
          // deptExistente = result['departamento'] as Departamento?;
          
          // Se encontrou no backend mas não existe localmente, adiciona ao manager
          if (matchedCode != null && !widget.barcodeManager.containsBarcode(matchedCode)) {
            debugPrint('🔍 [Scanner] Adicionando ao BarcodeManager: $matchedCode');
            // Cria o item local baseado nos dados do backend
            widget.barcodeManager.addBarcodeItem(
              BarcodeItem(code: matchedCode, status: BarcodeStatus.found),
            );
            // Adiciona detalhes se existirem
            final descricao = tombamentoBackend?['descricao']?.toString() ?? '';
            if (descricao.isNotEmpty) {
              widget.barcodeManager.mergeDetails({
                matchedCode: AssetDetails(code: matchedCode, descricao: descricao),
              });
            }
          }
        }
      } catch (e) {
        // Ignora erro de busca no backend
        debugPrint('Erro ao buscar no backend: $e');
      }
      // Se não encontrou nem localmente nem no backend, mostre mensagem explícita
      if (matchedCode == null) {
        // Verifica se há departamento vinculado a este código (pode retornar null)
        try {
          final deptSvc = DepartamentoService();
          final dept = await deptSvc.buscarDepartamentoPorTombamento(raw);
          if (dept == null && mounted) {
            // Mostra um dialog informativo explicito
            final escolha = await showDialog<String?>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Código não encontrado'),
                content: Text(
                  'O código "$raw" não está vinculado a nenhum departamento atualmente.\n\nDeseja atribuí-lo a um departamento agora, continuar e adicioná-lo como tombamento avulso, ou cancelar?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'cancel'),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'avulso'),
                    child: const Text('Continuar (avulso)'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, 'atribuir'),
                    child: const Text('Atribuir a um departamento'),
                  ),
                ],
              ),
            );

            if (escolha == 'cancel') {
              // Volta ao scanner sem processar
              if (mounted) {
                await _controller.start();
                setState(() => _isScanning = true);
              }
              return;
            }

            if (escolha == 'atribuir') {
              // Abrir seleção de departamento antes de continuar com status
              final departamento = await _showDepartamentoDialog(raw);
              if (departamento != null) {
                // cria flow: ask status then add to departamento
                final chosen = await pickBarcodeStatus(
                  context,
                  title: 'Selecione o status do código',
                );
                if (chosen != null) {
                  widget.barcodeManager.addBarcodeItem(BarcodeItem(code: raw, status: chosen));
                  await _askToAddPhoto(raw);
                  await _adicionarAoDepartamento(raw, departamento);
                }
                return;
              } else {
                // usuário cancelou atribuição, continuar normal
              }
            }
            // se escolha == 'avulso', apenas continua com o fluxo padrão abaixo
          }
        } catch (e) {
          debugPrint('Erro ao verificar departamento para código não encontrado: $e');
        }
      }
    }
    
    // Se encontrou match por sufixo (local ou backend), usa o código cadastrado
    // Caso contrário, usa o código raw escaneado
    final codeToUse = matchedCode ?? raw;
    debugPrint('🔍 [Scanner] codeToUse final: $codeToUse (alreadyExists: ${matchedCode != null})');
    
    // Verifica se já existe (usando o código resolvido)
    final alreadyExists = matchedCode != null;

    if (!alreadyExists) {
      // NOVO CÓDIGO: Perguntar status primeiro
      final chosen = await pickBarcodeStatus(
        context,
        title: 'Selecione o status do código',
      );
      if (chosen != null) {
        // Verificar se já existe detalhes para este código
        final existingDetails = widget.barcodeManager.getDetails(codeToUse);

        // Se não existe detalhes, perguntar se quer adicionar descrição
        if (existingDetails == null) {
          final description = await _showDescriptionDialog(codeToUse);
          if (description != null && description.isNotEmpty) {
            // Criar um AssetDetails com a descrição fornecida
            final newDetails = AssetDetails(
              code: codeToUse,
              descricao: description,
            );
            widget.barcodeManager.mergeDetails({
              codeToUse: newDetails,
            });
          }
        }

        final wasAdded = widget.barcodeManager.addBarcodeItem(
          BarcodeItem(code: codeToUse, status: chosen),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wasAdded
                    ? 'Código inserido: $codeToUse (status: ${chosen.label})'
                    : 'Código já adicionado anteriormente',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Perguntar se deseja adicionar foto APÓS selecionar status
        await _askToAddPhoto(codeToUse);
        
        // Perguntar se deseja enviar para um departamento
        final departamento = await _showDepartamentoDialog(codeToUse);
        if (departamento != null) {
          // Verifica se já existe em outro departamento
          final deptService = DepartamentoService();
          final deptAtual = await deptService.buscarDepartamentoPorTombamento(codeToUse);
          if (deptAtual != null && deptAtual.id != departamento.id) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Mover tombamento?'),
                content: Text(
                  'Este código já está vinculado ao departamento "${deptAtual.nome}".\n\nDeseja mover para o departamento "${departamento.nome}"?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Mover'),
                  ),
                ],
              ),
            );
            if (confirm != true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Operação cancelada.')),
                );
              }
              return;
            }
          }
          await _adicionarAoDepartamento(codeToUse, departamento);
        }
      }
    } else {
      // CÓDIGO JÁ EXISTE: Mostrar informações atuais para confirmação
      final existingItem = widget.barcodeManager.barcodes
          .firstWhere((item) => item.code == codeToUse);
      final existingDetails = widget.barcodeManager.getDetails(codeToUse);

      // Buscar departamento do código
      String deptInfo = '';
      Departamento? deptAtual;
      try {
        final deptService = DepartamentoService();
        deptAtual = await deptService.buscarDepartamentoPorTombamento(codeToUse);
        if (deptAtual != null) {
          deptInfo = '📍 ${deptAtual.nome}';
        }
      } catch (e) {
        // Ignora erro - não mostra departamento
      }

      // Mostrar código escaneado vs código encontrado (se diferente)
      String codeInfo = '';
      if (raw != codeToUse) {
        codeInfo = '🔍 Escaneado: $raw\n✅ Encontrado: $codeToUse\n\n';
      }

      final String descricao = existingDetails?.descricao ?? 'Sem descrição';

      // Dialog de confirmação com todas as informações
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Text(
                _getStatusEmoji(existingItem.status),
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Código: $codeToUse',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (codeInfo.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(codeInfo, style: const TextStyle(fontSize: 13)),
                  ),
                
                // Status atual
                _buildInfoRow('Status', existingItem.status.label, existingItem.status.color),
                const SizedBox(height: 8),
                
                // Descrição
                const Text('Descrição:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    descricao,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                
                if (deptInfo.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow('Departamento', deptAtual?.nome ?? '', Colors.blue),
                ],
                
                const SizedBox(height: 16),
                const Text(
                  'A descrição está correta?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'confirm'),
              child: const Text('✅ Confirmar', style: TextStyle(color: Colors.green)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'edit'),
              child: const Text('✏️ Editar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'status'),
              child: const Text('🔄 Alterar Status'),
            ),
          ],
        ),
      );

      if (action == 'confirm') {
        // Apenas confirma e continua
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $codeToUse confirmado!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        // Perguntar sobre foto
        await _askToAddPhoto(codeToUse);
        
      } else if (action == 'edit') {
        // Editar descrição
        final novaDescricao = await _showDescriptionDialog(codeToUse, descricaoAtual: descricao);
        if (novaDescricao != null && novaDescricao.isNotEmpty && novaDescricao != descricao) {
          // Atualizar descrição
          final newDetails = AssetDetails(
            code: codeToUse,
            descricao: novaDescricao,
            localizacao: existingDetails?.localizacao,
            valorAquisicao: existingDetails?.valorAquisicao,
          );
          widget.barcodeManager.mergeDetails({codeToUse: newDetails});
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Descrição atualizada!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        // Perguntar sobre foto
        await _askToAddPhoto(codeToUse);
        
      } else if (action == 'status') {
        // Alterar status
        final chosen = await pickBarcodeStatus(
          context,
          title: 'Selecione o novo status',
          initial: existingItem.status,
        );
        if (chosen != null) {
          widget.barcodeManager.updateBarcodeStatus(codeToUse, chosen);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status atualizado para: ${chosen.label}'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          // Perguntar sobre foto após alterar status
          await _askToAddPhoto(codeToUse);
        }
      }
    }

    // Retomar scanner
    if (mounted) {
      await _controller.start();
      setState(() {
        _isScanning = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner de Código')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Widget de câmera para escaneamento
                MobileScanner(
                  controller: _controller,
                  
                  /// Callback chamado quando um código é detectado pela câmera.
                  /// Implementa sistema de verificação tripla:
                  /// - Requer 3 leituras consecutivas do mesmo código
                  /// - Intervalo mínimo de 200ms entre leituras
                  /// - Feedback visual mostrando progresso (1/3, 2/3, 3/3)
                  onDetect: (capture) async {
                    // Validações iniciais
                    if (!_isScanning) return;  // Scanner pausado
                    final List<Barcode> barcodes = capture.barcodes;
                    if (barcodes.isEmpty) return;  // Nenhum código detectado
                    
                    final String raw = barcodes.first.rawValue ?? '';
                    if (raw.isEmpty) return;  // Código vazio
                    
                    final now = DateTime.now();
                    
                    // === LÓGICA DE VERIFICAÇÃO TRIPLA ===
                    
                    // Verificar se é o MESMO código da última leitura
                    if (_lastScannedCode == raw) {
                      // Validar se passou tempo suficiente desde última leitura (200ms)
                      if (_lastScanTime != null && now.difference(_lastScanTime!) >= _scanInterval) {
                        _consecutiveScans++;  // Incrementa contador
                        _lastScanTime = now;  // Atualiza timestamp
                        
                        // Atualiza UI com progresso visual
                        setState(() {
                          _barcode = '$raw (${_consecutiveScans}/$_requiredScans)';
                        });
                        
                        // Verifica se atingiu 3 leituras consecutivas
                        if (_consecutiveScans >= _requiredScans) {
                          // === CÓDIGO CONFIRMADO! ===
                          
                          // Resetar contadores para próxima leitura
                          _lastScannedCode = null;
                          _consecutiveScans = 0;
                          _lastScanTime = null;
                          
                          // Pausar scanner enquanto processa
                          _controller.stop();
                          setState(() {
                            _isScanning = false;
                          });
                          
                          // Se está em modo single scan, retorna o código e fecha
                          if (widget.singleScanMode) {
                            if (widget.onCodeScanned != null) {
                              widget.onCodeScanned!(raw);
                            }
                            if (mounted) {
                              Navigator.pop(context, raw);
                            }
                            return;
                          }
                          
                          // Processar o código confirmado (modo normal)
                          await _processConfirmedCode(raw);
                        }
                      }
                      // Se não passou intervalo mínimo, ignora esta leitura
                    } else {
                      // === CÓDIGO DIFERENTE detectado ===
                      // Resetar contador e iniciar nova sequência
                      _lastScannedCode = raw;
                      _consecutiveScans = 1;  // Primeira leitura deste código
                      _lastScanTime = now;
                      
                      // Atualiza UI mostrando novo código (1/3)
                      setState(() {
                        _barcode = '$raw (1/$_requiredScans)';
                      });
                    }
                  },
                ),
                
                // Botão flutuante para retomar scanning (aparece quando pausado)
                if (!_isScanning)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        _controller.start();
                        setState(() {
                          _isScanning = true;
                        });
                      },
                      child: const Text('Retomar'),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Último código lido:'),
                const SizedBox(height: 8),
                Text(_barcode, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _toggleScanning,
                      child: Text(_isScanning ? 'Parar' : 'Iniciar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _barcode = 'Nenhum código lido ainda';
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
