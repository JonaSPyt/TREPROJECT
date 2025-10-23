import 'package:flutter/material.dart';
import 'pages/scanner_screen.dart';
import 'pages/blank_screen.dart';
// Third screen removed; functionality merged into BlankScreen
import 'utils/barcode_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'services/csv_import_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manager = BarcodeManager();
  await manager.loadFromStorage();
  runApp(MyApp(barcodeManager: manager));
}

class MyApp extends StatelessWidget {
  final BarcodeManager barcodeManager;

  const MyApp({super.key, required this.barcodeManager});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: HomeScreen(barcodeManager: barcodeManager),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final BarcodeManager barcodeManager;

  const HomeScreen({super.key, required this.barcodeManager});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tela Inicial'),
      ),
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
            // (Third screen removed)
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['csv'],
            withData: true,
          );
          if (result == null || result.files.isEmpty) return;
          final file = result.files.single;
          final bytes = file.bytes;
          if (bytes == null) return;
          final items = CsvImportService.parseCsv(bytes);
          if (!context.mounted) return;

          if (items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV não contém patrimônios válidos.')),
            );
            return;
          }

          // Merge parsed items into shared BarcodeManager, skipping duplicates
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
          }

          // Open the combined list screen (BlankScreen) so user sees merged result
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BlankScreen(barcodeManager: barcodeManager),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
