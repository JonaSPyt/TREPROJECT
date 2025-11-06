import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'pages/scanner_screen.dart';
import 'pages/blank_screen.dart';
import 'utils/barcode_manager.dart';
import 'services/sync_service.dart';
import 'package:file_picker/file_picker.dart';
import 'services/csv_import_service.dart';
import 'theme/app_theme.dart';

/// Função principal de entrada do aplicativo.
/// 
/// Fluxo de inicialização:
/// 1. Inicializa binding do Flutter
/// 2. Carrega variáveis de ambiente (.env)
/// 3. Inicializa Firebase
/// 4. Cria e configura BarcodeManager
/// 5. Carrega dados locais (JSON)
/// 6. Configura SyncService
/// 7. Carrega dados do Firestore
/// 8. Inicia listener de sincronização em tempo real
/// 9. Executa o app
void main() async {
  // Necessário para usar métodos assíncronos antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega variáveis de ambiente do arquivo .env
  // Contém credenciais Firebase e outras configurações sensíveis
  await dotenv.load(fileName: ".env");

  // Inicializa Firebase com configurações específicas da plataforma
  // (Android/iOS) lidas do arquivo firebase_options.dart
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Cria gerenciador central de estado
  final manager = BarcodeManager();
  
  // Carrega dados persistidos localmente (códigos, detalhes, fotos)
  await manager.loadFromStorage();

  // ID do projeto no Firestore (compartilhado entre dispositivos)
  const projectId = 'patrimonio-projeto-compartilhado';

  // Cria serviço de sincronização bidirecional com Firebase
  final syncService = SyncService(
    barcodeManager: manager,
    projectId: projectId,
  );

  // Vincula serviço de sync ao manager para permitir uploads automáticos
  manager.setSyncService(syncService);

  // === CARREGAMENTO INICIAL DO FIRESTORE ===
  // Carrega dados da nuvem antes de iniciar o app para garantir
  // que o usuário veja informações atualizadas desde o início
  print('🔥 Iniciando carregamento do Firestore...');
  await syncService.loadItems();     // Carrega códigos escaneados
  await syncService.loadDetails();   // Carrega detalhes importados via CSV
  print('✅ Carregamento inicial concluído!');

  // Inicia aplicação
  runApp(MyApp(barcodeManager: manager, syncService: syncService));
}

/// Widget raiz do aplicativo.
/// Gerencia tema e navegação principal.
class MyApp extends StatefulWidget {
  final BarcodeManager barcodeManager;
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.barcodeManager,
    required this.syncService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    
    // Inicia listener de sincronização em tempo real
    // Detecta mudanças no Firestore e atualiza dados locais automaticamente
    // O listen vazio é intencional - as atualizações são tratadas dentro do stream
    widget.syncService.listenToChanges().listen((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,  // Remove banner de debug
      
      // Temas personalizados (claro e escuro)
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,  // Segue configuração do sistema
      
      home: HomeScreen(barcodeManager: widget.barcodeManager),
    );
  }
}

/// Tela inicial do aplicativo com navegação principal.
/// Fornece acesso ao scanner e à lista de códigos.
class HomeScreen extends StatelessWidget {
  final BarcodeManager barcodeManager;

  const HomeScreen({super.key, required this.barcodeManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tela Inicial')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ScannerScreen(barcodeManager: barcodeManager),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: const Text('Scanner', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BlankScreen(barcodeManager: barcodeManager),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: const Text('Outra Tela', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['csv'],
              withData: true,
            );

            if (result == null || result.files.isEmpty) return;

            final file = result.files.single;
            final bytes = file.bytes;

            if (bytes == null) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao ler arquivo CSV.')),
                );
              }
              return;
            }

            final parsed = CsvImportService.parseCsvWithDetails(bytes);
            barcodeManager.mergeDetails(parsed.detailsByCode);
            final items = parsed.items;

            if (!context.mounted) return;

            if (items.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV não contém patrimônios válidos.'),
                ),
              );
              return;
            }

            int added = 0;
            int skipped = 0;
            for (final it in items) {
              final wasAdded = barcodeManager.addBarcodeItem(it);
              if (wasAdded) {
                added++;
              } else {
                skipped++;
              }
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Importado: $added, Ignorados: $skipped'),
                  duration: const Duration(seconds: 3),
                ),
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BlankScreen(barcodeManager: barcodeManager),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao importar CSV: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
