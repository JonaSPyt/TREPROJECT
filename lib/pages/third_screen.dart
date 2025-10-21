import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/barcode_manager.dart';
import '../widgets/barcode_list_widget.dart';

class ThirdScreen extends StatefulWidget {
  final List<BarcodeItem> items;

  const ThirdScreen({super.key, required this.items});

  @override
  State<ThirdScreen> createState() => _ThirdScreenState();
}

class _ThirdScreenState extends State<ThirdScreen> {
  late List<BarcodeItem> _items;

  Future<File> _getStorageFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/third_items.json');
  }

  Future<void> _saveItems() async {
    try {
      final file = await _getStorageFile();
      final jsonList = _items.map((e) => e.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (_) {
      // ignore write errors silently for now
    }
  }

  Future<void> _loadItems() async {
    try {
      final file = await _getStorageFile();
      if (!await file.exists()) return;
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        final loaded = decoded
            .whereType<Map<String, dynamic>>()
            .map((m) => BarcodeItem.fromMap(m))
            .toList();
        if (!mounted) return;
        setState(() => _items = loaded);
      }
    } catch (_) {
      // ignore read/parse errors
    }
  }

  @override
  void initState() {
    super.initState();
    _items = [];
    // Initialize from passed items (from CSV) or load from local storage
    Future.microtask(() async {
      if (widget.items.isNotEmpty) {
        if (!mounted) return;
        setState(() => _items = [...widget.items]);
        await _saveItems();
      } else {
        await _loadItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Terceira Tela'),
      ),
      body: BarcodeListWidget(
        barcodes: _items,
        onDelete: (code) {
          setState(() {
            _items.removeWhere((e) => e.code == code);
          });
          _saveItems();
        },
        onStatusChange: (code, status) {
          setState(() {
            final idx = _items.indexWhere((e) => e.code == code);
            if (idx != -1) {
              _items[idx].status = status;
            }
          });
          _saveItems();
        },
      ),
    );
  }
}
