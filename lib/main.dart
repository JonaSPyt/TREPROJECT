import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/scanner_screen.dart';
import 'pages/blank_screen.dart';
import 'utils/barcode_manager.dart';
import 'services/sync_service.dart';
import 'package:file_picker/file_picker.dart';
import 'services/csv_import_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final manager = BarcodeManager();
  await manager.loadFromStorage();

  const projectId = 'patrimonio-projeto-compartilhado';

  final syncService = SyncService(
    barcodeManager: manager,
    projectId: projectId,
  );

  manager.setSyncService(syncService);

  // CORREÇÃO: Carrega TANTO items quanto details do Firestore
  print('🔥 Iniciando carregamento do Firestore...');
  await syncService.loadItems(); // ← NOVO: Carrega códigos escaneados
  await syncService.loadDetails(); // ← Carrega detalhes do CSV
  print('✅ Carregamento inicial concluído!');

  runApp(MyApp(barcodeManager: manager, syncService: syncService));
}

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
    // Inicia sincronização em tempo real
    widget.syncService.listenToChanges().listen((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(barcodeManager: widget.barcodeManager),
    );
  }
}

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
