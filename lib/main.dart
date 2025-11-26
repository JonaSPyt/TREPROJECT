import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/scanner_screen.dart';
import 'pages/blank_screen.dart';
import 'utils/barcode_manager.dart';
import 'services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'services/csv_import_service.dart';
import 'services/pdf_import_service.dart';
import 'theme/app_theme.dart';

/// Função principal de entrada do aplicativo.
/// 
/// Fluxo de inicialização:
/// 1. Inicializa binding do Flutter
/// 2. Carrega variáveis de ambiente (.env)
/// 3. Cria e configura BarcodeManager
/// 4. Carrega dados locais (JSON)
/// 5. Configura ApiService (API interna da empresa)
/// 6. Verifica conexão com a API
/// 7. Carrega dados da API interna
/// 8. Executa o app
void main() async {
  // Necessário para usar métodos assíncronos antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega variáveis de ambiente do arquivo .env
  // Contém URL da API interna
  print('📋 Carregando variáveis de ambiente...');
  await dotenv.load(fileName: ".env");
  print('✅ Arquivo .env carregado!');
  print('🔧 API_BASE_URL: ${dotenv.env['API_BASE_URL'] ?? 'NÃO DEFINIDA'}');

  // Cria gerenciador central de estado
  final manager = BarcodeManager();
  
  // Carrega dados persistidos localmente (códigos, detalhes, fotos)
  print('💾 Carregando dados locais...');
  await manager.loadFromStorage();
  print('✅ Dados locais carregados!');

  // Cria serviço de API interna (WiFi da empresa)
  final apiService = ApiService(barcodeManager: manager);

  // Vincula serviço de API ao manager para permitir sincronização automática
  manager.setSyncService(apiService);

  // === VERIFICAÇÃO DE CONECTIVIDADE ===
  print('🔍 Verificando conexão com API interna...');
  final isConnected = await apiService.checkConnection();
  
  if (isConnected) {
    // === CARREGAMENTO INICIAL DA API ===
    print('🌐 Iniciando carregamento da API interna...');
    await apiService.loadItems();     // Carrega tombamentos
    await apiService.loadDetails();   // Carrega detalhes dos patrimônios
    print('✅ Carregamento inicial concluído!');
  } else {
    print('⚠️  Não foi possível conectar com a API.');
    print('⚠️  O app funcionará offline com dados locais.');
  }

  // Inicia aplicação
  runApp(MyApp(
    barcodeManager: manager,
    apiService: apiService,
  ));
}

/// Widget raiz do aplicativo.
/// Gerencia tema e navegação principal.
class MyApp extends StatelessWidget {
  final BarcodeManager barcodeManager;
  final ApiService apiService;

  const MyApp({
    super.key,
    required this.barcodeManager,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema de Inventário',
      debugShowCheckedModeBanner: false,  // Remove banner de debug
      
      // Temas personalizados (claro e escuro)
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,  // Segue configuração do sistema
      
      home: HomeScreen(
        barcodeManager: barcodeManager,
        apiService: apiService,
      ),
    );
  }
}

/// Tela inicial do aplicativo com navegação principal.
/// Fornece acesso ao scanner e à lista de códigos.
class HomeScreen extends StatelessWidget {
  final BarcodeManager barcodeManager;
  final ApiService apiService;

  const HomeScreen({
    super.key, 
    required this.barcodeManager,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tela Iniciall')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ScannerScreen(
                      barcodeManager: barcodeManager,
                      apiService: apiService,
                    ),
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
                    builder: (context) => BlankScreen(
                      barcodeManager: barcodeManager,
                      apiService: apiService,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: const Text('Outra Telaa', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
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
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao ler arquivo.')),
                );
              }
              return;
            }

            // Detecta tipo do arquivo e parseia apropriadamente
            final extension = file.extension?.toLowerCase();
            late final dynamic parsed;
            
            if (extension == 'pdf') {
              print('📄 Importando PDF...');
              parsed = await PdfImportService.parsePdfWithDetails(bytes);
            } else {
              print('📊 Importando CSV...');
              parsed = CsvImportService.parseCsvWithDetails(bytes);
            }
            
            barcodeManager.mergeDetails(parsed.detailsByCode);
            final items = parsed.items;

            if (!context.mounted) return;

            if (items.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${extension == 'pdf' ? 'PDF' : 'CSV'} não contém patrimônios válidos.'),
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
                  content: Text('${extension == 'pdf' ? 'PDF' : 'CSV'} importado: $added novos, $skipped já existiam'),
                  duration: const Duration(seconds: 3),
                ),
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlankScreen(
                    barcodeManager: barcodeManager,
                    apiService: apiService,
                  ),
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
