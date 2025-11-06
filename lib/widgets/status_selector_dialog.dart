import 'package:flutter/material.dart';
import '../utils/barcode_manager.dart';

/// Exibe um dialog modal para seleção de status de patrimônio.
/// 
/// Este widget fornece uma interface intuitiva para escolher entre os
/// diferentes estados possíveis de um patrimônio durante o inventário.
/// 
/// Cada opção de status é exibida com:
/// - Círculo colorido (indicador visual)
/// - Label descritivo
/// - Checkmark se for o status atual (quando `initial` é fornecido)
/// 
/// Uso típico:
/// ```dart
/// final status = await pickBarcodeStatus(
///   context,
///   title: 'Selecionar Status',
///   initial: BarcodeStatus.found,
/// );
/// 
/// if (status != null) {
///   // Usuário selecionou um status
///   manager.updateBarcodeStatus(code, status);
/// } else {
///   // Usuário cancelou
/// }
/// ```
/// 
/// Parâmetros:
/// - context: BuildContext necessário para mostrar o dialog
/// - title: Título do dialog (padrão: 'Selecionar Status')
/// - initial: Status atual para marcar com checkmark (opcional)
/// 
/// Returns:
/// - BarcodeStatus selecionado, ou null se usuário cancelou
Future<BarcodeStatus?> pickBarcodeStatus(
  BuildContext context, {
  String title = 'Selecionar Status',
  BarcodeStatus? initial,
}) {
  // Lista de todos os status disponíveis (exceto 'none')
  const options = <BarcodeStatus>[
    BarcodeStatus.found,           // Verde - Tudo OK
    BarcodeStatus.foundNotRelated, // Roxo - Encontrado mas não relacionado
    BarcodeStatus.notRegistered,   // Azul claro - Sem identificação
    BarcodeStatus.damaged,         // Laranja - Danificado
    BarcodeStatus.notFound,        // Vermelho - Não localizado
  ];

  return showDialog<BarcodeStatus>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,  // Ajusta altura ao conteúdo
          children: options
              .map((s) => ListTile(
                    // Círculo colorido como indicador visual
                    leading: CircleAvatar(
                      backgroundColor: s.color, 
                      radius: 12
                    ),
                    
                    // Label do status
                    title: Text(s.label),
                    
                    // Checkmark se for o status atual
                    trailing: initial == s
                        ? Icon(
                            Icons.check, 
                            color: Theme.of(context).colorScheme.primary
                          )
                        : null,
                    
                    // Ao tocar, fecha dialog retornando status selecionado
                    onTap: () => Navigator.pop(context, s),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),  // Retorna null
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );
}
