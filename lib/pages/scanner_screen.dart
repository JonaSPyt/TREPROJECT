import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/barcode_manager.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/status_selector_dialog.dart';

/// Tela de escaneamento de códigos de barras.
/// Implementa sistema de verificação tripla para garantir leituras intencionais.
class ScannerScreen extends StatefulWidget {
  final BarcodeManager barcodeManager;

  const ScannerScreen({super.key, required this.barcodeManager});

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

      // Vincula foto ao código
      await widget.barcodeManager.setPhotoForCode(code, dest.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto vinculada com sucesso.')),
        );
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

  /// Exibe dialog para adicionar descrição opcional ao patrimônio.
  /// Retorna a descrição digitada ou null se usuário pulou/cancelou.
  Future<String?> _showDescriptionDialog(String code) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Descrição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Código: $code'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                hintText: 'Digite uma descrição para este item',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Pular'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  /// Processa um código após confirmação (3 leituras consecutivas).
  /// 
  /// Fluxo:
  /// 1. Normaliza o código (remove prefixo e zeros à esquerda)
  /// 2. Verifica se código já existe (raw ou truncado)
  /// 3. Se novo: pede status, descrição e foto
  /// 4. Se existente: mostra informações atuais
  Future<void> _processConfirmedCode(String raw) async {
    // Normalização: remove primeiros 3 caracteres e zeros à esquerda
    String truncated = raw.length > 3 ? raw.substring(3) : '';
    truncated = truncated.replaceFirst(RegExp(r'^0+'), '');

    // Determine presence of raw and truncated
    final hasRaw = raw.isNotEmpty && widget.barcodeManager.containsBarcode(raw);
    final hasTrunc = truncated.isNotEmpty && widget.barcodeManager.containsBarcode(truncated);

    // Decide code to add (new) or existing code (duplicate)
    String? codeToAdd;
    String? existingCode;
    if (truncated.isNotEmpty && !hasTrunc && !hasRaw) {
      codeToAdd = truncated;
    } else if (raw.isNotEmpty && !hasRaw && !hasTrunc) {
      codeToAdd = raw;
    } else if (hasRaw || hasTrunc) {
      existingCode = hasRaw ? raw : truncated;
    }

    if (codeToAdd != null) {
      // NOVO CÓDIGO: Perguntar status primeiro
      final chosen = await pickBarcodeStatus(
        context,
        title: 'Selecione o status do código',
      );
      if (chosen != null) {
        // Verificar se já existe detalhes para este código
        final existingDetails = widget.barcodeManager.getDetails(codeToAdd);

        // Se não existe detalhes, perguntar se quer adicionar descrição
        if (existingDetails == null) {
          final description = await _showDescriptionDialog(codeToAdd);
          if (description != null && description.isNotEmpty) {
            // Criar um AssetDetails com a descrição fornecida
            final newDetails = AssetDetails(
              code: codeToAdd,
              descricao: description,
            );
            widget.barcodeManager.mergeDetails({
              codeToAdd: newDetails,
            });
          }
        }

        final wasAdded = widget.barcodeManager.addBarcodeItem(
          BarcodeItem(code: codeToAdd, status: chosen),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                wasAdded
                    ? 'Código inserido: $codeToAdd (status: ${chosen.label})'
                    : 'Código já adicionado anteriormente',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Perguntar se deseja adicionar foto APÓS selecionar status
        await _askToAddPhoto(codeToAdd);
      }
    } else if (existingCode != null) {
      // CÓDIGO JÁ EXISTE: Mostrar informações atuais
      final existingItem = widget.barcodeManager.barcodes
          .firstWhere((item) => item.code == existingCode);
      final existingDetails = widget.barcodeManager.getDetails(existingCode);

      final String statusInfo = 'Status atual: ${existingItem.status.label}';
      final String descInfo = existingDetails?.descricao != null &&
              existingDetails!.descricao!.isNotEmpty
          ? '\nDescrição: ${existingDetails.descricao}'
          : '\nSem descrição';

      // Perguntar se deseja manter ou alterar status
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código já existente'),
          content: Text(
            'Este código já está na lista.\n\n$statusInfo$descInfo\n\nDeseja manter o status atual ou alterar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'keep'),
              child: const Text('Manter'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'change'),
              child: const Text('Alterar'),
            ),
          ],
        ),
      );

      if (action == 'change') {
        final chosen = await pickBarcodeStatus(
          context,
          title: 'Selecione o novo status',
          initial: existingItem.status,
        );
        if (chosen != null) {
          widget.barcodeManager.updateBarcodeStatus(
            existingCode,
            chosen,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Status atualizado para: ${chosen.label}',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }

          // Perguntar sobre foto após alterar status
          await _askToAddPhoto(existingCode);
        }
      } else if (action == 'keep') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status mantido.'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Ainda perguntar sobre foto mesmo mantendo status
        await _askToAddPhoto(existingCode);
      }
    } else {
      // invalid empty read
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leitura inválida.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
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
                          
                          // Processar o código confirmado
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
