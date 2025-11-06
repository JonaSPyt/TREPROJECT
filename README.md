# 📱 TreProject - Sistema de Inventário com Escaneamento de Código de Barras

> Sistema completo de gerenciamento de patrimônio com leitura de códigos de barras, sincronização em nuvem e exportação de dados.

[![Flutter](https://img.shields.io/badge/Flutter-3.8.0-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-Private-red.svg)]()

---

## 📋 Índice

- [Visão Geral](#-visão-geral)
- [Funcionalidades Principais](#-funcionalidades-principais)
- [Arquitetura do Sistema](#-arquitetura-do-sistema)
- [Tecnologias Utilizadas](#-tecnologias-utilizadas)
- [Estrutura de Pastas](#-estrutura-de-pastas)
- [Configuração e Instalação](#-configuração-e-instalação)
- [Funcionalidades Detalhadas](#-funcionalidades-detalhadas)
- [Fluxo de Dados](#-fluxo-de-dados)
- [Segurança](#-segurança)
- [API e Serviços](#-api-e-serviços)
- [Gestão de Estado](#-gestão-de-estado)
- [Sistema de Status](#-sistema-de-status)
- [Exportação de Dados](#-exportação-de-dados)
- [Desenvolvimento](#-desenvolvimento)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Visão Geral

O **TreProject** é uma aplicação móvel desenvolvida em Flutter para gerenciamento de inventário patrimonial com as seguintes características principais:

- **Escaneamento Inteligente**: Sistema de verificação tripla com intervalos de 200ms para evitar leituras acidentais
- **Sincronização em Tempo Real**: Integração com Firebase Firestore para backup e sincronização entre dispositivos
- **Gestão de Fotos**: Captura e gerenciamento de fotos vinculadas a cada patrimônio
- **Importação CSV**: Importação em lote de dados patrimoniais
- **Exportação Completa**: Geração de arquivos ZIP com dados e fotos
- **Múltiplos Status**: Sistema de categorização com 5 estados diferentes
- **Segurança**: Credenciais protegidas com variáveis de ambiente

---

## ✨ Funcionalidades Principais

### 🔍 Escaneamento Inteligente de Códigos

O sistema implementa um mecanismo de **verificação tripla** para garantir leituras intencionais:

1. **Primeira Leitura**: Sistema detecta o código e inicia contagem (1/3)
2. **Segunda Leitura**: Aguarda mínimo 200ms e valida mesmo código (2/3)
3. **Terceira Leitura**: Confirma e processa o código (3/3)

**Benefícios**:
- ✅ Elimina leituras acidentais
- ✅ Garante foco deliberado no código
- ✅ Feedback visual em tempo real
- ✅ Contador reseta ao mudar de código

### 📸 Gestão de Fotos

Cada patrimônio pode ter uma foto vinculada com as seguintes operações:

- **Adicionar Foto**: Via câmera ou galeria após seleção de status
- **Visualizar Foto**: Expansão em tela cheia
- **Compartilhar Foto**: Envio direto da foto individual
- **Substituir Foto**: Trocar por nova captura ou seleção da galeria
- **Remover Foto**: Exclusão com confirmação

**Armazenamento**: 
- Local: `<DocumentDirectory>/photos/`
- Nomenclatura: `<timestamp>_<codigo>.jpg`
- Sincronização: Caminho salvo no Firestore

### 🔄 Sincronização em Nuvem

**Arquitetura de Sincronização**:

```
Local (BarcodeManager) ←→ Firebase Firestore
         ↓                        ↓
   _barcodes list          items collection
   _detailsByCode map      details collection
   _photoByCode map        (path references)
```

**Estratégia de Sincronização**:
- **Upward Sync**: Alterações locais → Firebase (automático)
- **Downward Sync**: Firebase → Local (listener em tempo real)
- **Conflict Resolution**: Last-write-wins
- **Silent Updates**: Evita loops de notificação

### 📊 Importação CSV

Importa dados patrimoniais em massa com as seguintes colunas:

| Coluna | Descrição | Obrigatório |
|--------|-----------|-------------|
| Patrimônio | Código identificador | ✅ Sim |
| Item | Número do item | Não |
| P. Antigo | Código antigo | Não |
| Descrição | Detalhes do bem | Não |
| Localização | Local atual | Não |
| VI. Aquisição (R$) | Valor de compra | Não |

**Funcionalidades**:
- ✅ Auto-detecção de colunas por nome
- ✅ Preservação de zeros à esquerda
- ✅ Parsing de flags de status
- ✅ Merge inteligente com dados existentes

### 📦 Exportação de Dados

Gera arquivo ZIP contendo:

```
exportacao_<timestamp>.zip
├── codigos_barras.txt      # Lista formatada com status
└── <codigo_1>.jpg          # Foto do patrimônio 1
└── <codigo_2>.jpg          # Foto do patrimônio 2
└── ...
```

**Formato do TXT**:
```
Lista de Códigos de Barras
Data: 2025-11-06 14:30:00
Total: 25 códigos

==================================================

[1] 12345678
    Status: Encontrado sem nenhuma pendência
    Data: 2025-11-06 10:15

[2] 87654321
    Status: Bens não encontrados
    Data: 2025-11-06 11:20
...
```

---

## 🏗️ Arquitetura do Sistema

### Padrões Arquiteturais

```
┌─────────────────────────────────────────┐
│           Presentation Layer            │
│  (Screens, Widgets, Dialogs)            │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         Business Logic Layer            │
│  (BarcodeManager - ChangeNotifier)      │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│          Service Layer                  │
│  (SyncService, CsvImportService)        │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│          Data Layer                     │
│  (Firebase, Local Storage, File System) │
└─────────────────────────────────────────┘
```

### Componentes Principais

#### 1. **BarcodeManager** (`lib/utils/barcode_manager.dart`)

Gerenciador central de estado que implementa `ChangeNotifier`.

**Responsabilidades**:
- Gerenciar lista de códigos escaneados
- Armazenar detalhes patrimoniais (CSV)
- Gerenciar caminhos de fotos
- Persistir dados localmente (JSON)
- Notificar listeners de mudanças
- Interface com SyncService

**Estado Gerenciado**:
```dart
List<BarcodeItem> _barcodes           // Códigos escaneados
Map<String, AssetDetails> _detailsByCode  // Detalhes do CSV
Map<String, String> _photoByCode      // Caminhos das fotos
```

**Métodos Principais**:
```dart
// Operações com notificação
bool addBarcodeItem(BarcodeItem item)
void updateBarcodeStatus(String code, BarcodeStatus status)
void removeBarcode(String code)
void mergeDetails(Map<String, AssetDetails> map)

// Operações silenciosas (para sync)
void addBarcodeItemSilent(BarcodeItem item)
void removeBarcodeSilent(String code)
void mergeDetailsSilent(Map<String, AssetDetails> map)

// Gestão de fotos
Future<void> setPhotoForCode(String code, String path)
Future<void> removePhotoForCode(String code)

// Persistência
Future<void> loadFromStorage()
Future<void> _saveToStorage()
```

#### 2. **SyncService** (`lib/services/sync_service.dart`)

Responsável pela sincronização bidirecional com Firebase.

**Funcionalidades**:
- Upload de alterações locais para Firestore
- Download de dados iniciais do Firestore
- Listener de mudanças em tempo real
- Prevenção de loops de sincronização

**Coleções Firestore**:
```
/projects/{projectId}/items/{code}
/projects/{projectId}/details/{code}
```

**Fluxo de Sincronização**:
```dart
// Inicialização
await syncService.loadItems()    // Carrega códigos escaneados
await syncService.loadDetails()  // Carrega detalhes CSV

// Tempo real
syncService.listenToChanges().listen((_) {})

// Upload automático
manager.addBarcodeItem(item)  → syncService.syncItem(item)
```

#### 3. **CsvImportService** (`lib/services/csv_import_service.dart`)

Parser e processador de arquivos CSV.

**Recursos**:
- Auto-detecção de colunas
- Suporte a múltiplos delimitadores
- Parsing de valores com encoding especial
- Extração de status de flags booleanas
- Geração de objetos `AssetDetails`

**Formato de Saída**:
```dart
class CsvParseResult {
  List<BarcodeItem> items;           // Códigos encontrados
  Map<String, AssetDetails> detailsByCode;  // Detalhes completos
}
```

#### 4. **BarcodeExporter** (`lib/utils/barcode_exporter.dart`)

Gerador de exportações em formato ZIP.

**Processo**:
1. Criar diretório temporário
2. Gerar arquivo TXT formatado
3. Copiar fotos com renomeação
4. Compactar tudo em ZIP
5. Compartilhar via Share API

---

## 🛠️ Tecnologias Utilizadas

### Framework e Linguagem

- **Flutter**: `^3.8.0` - Framework multiplataforma
- **Dart**: SDK incluído no Flutter

### Dependências Principais

#### Firebase
```yaml
firebase_core: ^4.2.0          # Inicialização Firebase
cloud_firestore: ^6.0.3        # Banco de dados NoSQL
```

#### Escaneamento
```yaml
mobile_scanner: ^3.0.0         # Leitura de códigos de barras/QR
```

#### Mídia
```yaml
image_picker: ^1.0.7           # Seleção de fotos (câmera/galeria)
```

#### Arquivos
```yaml
file_picker: ^8.0.0            # Seleção de arquivos
path_provider: ^2.1.0          # Acesso a diretórios do sistema
share_plus: ^7.2.0             # Compartilhamento de arquivos
archive: ^3.4.10               # Compactação ZIP
csv: ^6.0.0                    # Parser CSV
```

#### Segurança
```yaml
flutter_dotenv: ^5.1.0         # Variáveis de ambiente
```

### Permissões

#### Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

#### iOS (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>O aplicativo precisa acessar a câmera para escanear códigos de barras.</string>
```

---

## 📁 Estrutura de Pastas

```
TREPROJECT/
├── lib/
│   ├── main.dart                    # Entry point, inicialização Firebase
│   ├── firebase_options.dart        # Configurações Firebase (lê .env)
│   │
│   ├── pages/                       # Telas da aplicação
│   │   ├── blank_screen.dart        # Lista de códigos escaneados
│   │   └── scanner_screen.dart      # Tela de escaneamento com câmera
│   │
│   ├── widgets/                     # Componentes reutilizáveis
│   │   ├── barcode_list_widget.dart # Lista customizada de códigos
│   │   └── status_selector_dialog.dart # Dialog de seleção de status
│   │
│   ├── services/                    # Camada de serviços
│   │   ├── sync_service.dart        # Sincronização Firebase
│   │   └── csv_import_service.dart  # Importação CSV
│   │
│   ├── utils/                       # Utilitários
│   │   ├── barcode_manager.dart     # Gerenciador central de estado
│   │   └── barcode_exporter.dart    # Exportação ZIP
│   │
│   └── theme/                       # Tema e cores
│       ├── app_theme.dart           # Definições de tema claro/escuro
│       └── app_colors.dart          # Paleta de cores
│
├── android/                         # Configuração Android
│   └── app/
│       ├── build.gradle.kts         # Build configuration
│       └── src/main/AndroidManifest.xml
│
├── ios/                             # Configuração iOS
│   └── Runner/
│       └── Info.plist               # Permissões iOS
│
├── .env                             # Variáveis de ambiente (gitignored)
├── .env.example                     # Template de variáveis
├── .gitignore                       # Arquivos ignorados pelo Git
├── pubspec.yaml                     # Dependências Flutter
└── README.md                        # Esta documentação
```

---

## ⚙️ Configuração e Instalação

### Pré-requisitos

1. **Flutter SDK**: versão `>=3.8.0`
   ```bash
   flutter --version
   ```

2. **Android Studio / Xcode**: Para compilar para Android/iOS

3. **Firebase Project**: Projeto configurado no Firebase Console

### Instalação Passo a Passo

#### 1. Clone o Repositório

```bash
git clone https://github.com/JonaSPyt/TREPROJECT.git
cd TREPROJECT
```

#### 2. Configure Variáveis de Ambiente

Crie arquivo `.env` na raiz do projeto:

```env
# Firebase Android
FIREBASE_ANDROID_API_KEY=sua_chave_aqui
FIREBASE_ANDROID_APP_ID=seu_app_id_aqui
FIREBASE_ANDROID_MESSAGING_SENDER_ID=seu_sender_id_aqui
FIREBASE_ANDROID_PROJECT_ID=seu_project_id_aqui
FIREBASE_ANDROID_STORAGE_BUCKET=seu_bucket_aqui

# Firebase iOS
FIREBASE_IOS_API_KEY=sua_chave_aqui
FIREBASE_IOS_APP_ID=seu_app_id_aqui
FIREBASE_IOS_MESSAGING_SENDER_ID=seu_sender_id_aqui
FIREBASE_IOS_PROJECT_ID=seu_project_id_aqui
FIREBASE_IOS_STORAGE_BUCKET=seu_bucket_aqui
FIREBASE_IOS_BUNDLE_ID=com.example.treproject
```

**⚠️ IMPORTANTE**: Nunca commite o arquivo `.env` no Git!

#### 3. Instale Dependências

```bash
flutter pub get
```

#### 4. Configure Firebase

**Android**: 
- Baixe `google-services.json` do Firebase Console
- Coloque em `android/app/`

**iOS**:
- Baixe `GoogleService-Info.plist` do Firebase Console
- Adicione ao projeto Xcode em `ios/Runner/`

#### 5. Execute o Aplicativo

```bash
# Verificar dispositivos conectados
flutter devices

# Executar no dispositivo/emulador
flutter run
```

### Configuração do Firestore

Crie as seguintes regras de segurança no Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /projects/{projectId}/items/{itemId} {
      allow read, write: if true; // Ajuste conforme suas necessidades
    }
    match /projects/{projectId}/details/{detailId} {
      allow read, write: if true; // Ajuste conforme suas necessidades
    }
  }
}
```

**Estrutura de Coleções**:

```
projects/
  └── patrimonio-projeto-compartilhado/
      ├── items/
      │   └── {code}/
      │       ├── code: string
      │       ├── status: number
      │       ├── description: string
      │       ├── photoPath: string
      │       └── timestamp: timestamp
      │
      └── details/
          └── {code}/
              ├── item: string
              ├── oldCode: string
              ├── description: string
              ├── location: string
              └── acquisitionValue: string
```

---

## 📖 Funcionalidades Detalhadas

### 1. Escaneamento de Códigos

#### Scanner Screen (`lib/pages/scanner_screen.dart`)

**Inicialização**:
```dart
final MobileScannerController _controller = MobileScannerController();
```

**Variáveis de Estado**:
```dart
String? _lastScannedCode;              // Último código lido
int _consecutiveScans = 0;             // Contador (0-3)
DateTime? _lastScanTime;               // Timestamp da última leitura
static const _scanInterval = Duration(milliseconds: 200);
static const _requiredScans = 3;      // Requer 3 leituras
```

**Fluxo de Detecção**:

```dart
onDetect: (capture) async {
  // 1. Validações iniciais
  if (!_isScanning) return;
  if (barcodes.isEmpty) return;
  
  final String raw = barcodes.first.rawValue ?? '';
  if (raw.isEmpty) return;
  
  final now = DateTime.now();
  
  // 2. Verificar se é o mesmo código
  if (_lastScannedCode == raw) {
    // 2a. Validar intervalo de tempo
    if (_lastScanTime != null && 
        now.difference(_lastScanTime!) >= _scanInterval) {
      
      _consecutiveScans++;
      _lastScanTime = now;
      
      // 2b. Atualizar UI com progresso
      setState(() {
        _barcode = '$raw (${_consecutiveScans}/$_requiredScans)';
      });
      
      // 2c. Processar se atingiu 3 leituras
      if (_consecutiveScans >= _requiredScans) {
        _resetCounters();
        _controller.stop();
        setState(() { _isScanning = false; });
        await _processConfirmedCode(raw);
      }
    }
  } else {
    // 3. Código diferente, resetar e iniciar nova contagem
    _lastScannedCode = raw;
    _consecutiveScans = 1;
    _lastScanTime = now;
    setState(() {
      _barcode = '$raw (1/$_requiredScans)';
    });
  }
}
```

**Processamento do Código** (`_processConfirmedCode`):

```dart
// 1. Normalização
String truncated = raw.length > 3 ? raw.substring(3) : '';
truncated = truncated.replaceFirst(RegExp(r'^0+'), '');

// 2. Verificar existência
final hasRaw = manager.containsBarcode(raw);
final hasTrunc = manager.containsBarcode(truncated);

// 3. Decisão de fluxo
if (/* código novo */) {
  // 3a. Selecionar status
  final status = await pickBarcodeStatus(context);
  
  // 3b. Adicionar descrição (opcional)
  final description = await _showDescriptionDialog(code);
  
  // 3c. Perguntar sobre foto
  await _askToAddPhoto(code);
  
} else {
  // 3d. Código já existe, mostrar informações
  showDialog(
    content: Text('Status: ${item.status.label}\n'
                  'Descrição: ${details?.description}')
  );
}
```

#### Dialog de Foto (`_askToAddPhoto`)

```dart
AlertDialog(
  title: Text('Deseja adicionar uma foto?'),
  actions: [
    TextButton('Pular'),
    TextButton('Galeria') → _pickAndLinkPhoto(code, ImageSource.gallery),
    TextButton('Câmera') → _pickAndLinkPhoto(code, ImageSource.camera),
  ]
)
```

#### Captura e Armazenamento de Foto

```dart
Future<void> _pickAndLinkPhoto(String code, ImageSource source) async {
  // 1. Selecionar/capturar imagem
  final picker = ImagePicker();
  final XFile? picked = await picker.pickImage(
    source: source,
    maxWidth: 1920,
    maxHeight: 1080,
    imageQuality: 85,
  );
  
  // 2. Preparar diretório
  final docs = await getApplicationDocumentsDirectory();
  final photosDir = Directory('${docs.path}/photos');
  await photosDir.create(recursive: true);
  
  // 3. Copiar com nome único
  final filename = '${DateTime.now().millisecondsSinceEpoch}_$code.jpg';
  final dest = File('${photosDir.path}/$filename');
  await File(picked.path).copy(dest.path);
  
  // 4. Vincular ao código
  await barcodeManager.setPhotoForCode(code, dest.path);
  
  // 5. Sincronizar com Firebase
  // (feito automaticamente pelo BarcodeManager)
}
```

### 2. Lista de Códigos

#### Blank Screen (`lib/pages/blank_screen.dart`)

**Exibição**:
```dart
BarcodeListWidget(
  barcodes: barcodeManager.barcodes,
  onDelete: (code) => barcodeManager.removeBarcode(code),
  onStatusChange: (code, status) => 
    barcodeManager.updateBarcodeStatus(code, status),
  onTapItem: (item) => _showDetailModal(item),
  getPhotoPath: (code) => barcodeManager.getPhotoPath(code),
)
```

**Modal de Detalhes**:

Ao tocar em um item, abre modal com:
- Foto (se existir) com botões de ação
- Código do patrimônio
- Status atual
- Descrição
- Detalhes do CSV (se existir):
  - Item
  - Código antigo
  - Localização
  - Valor de aquisição

**Botões de Ação da Foto**:
```dart
Wrap(
  children: [
    IconButton(icon: Icons.visibility) → _viewFullPhoto(),
    IconButton(icon: Icons.share) → Share.shareXFiles([photo]),
    IconButton(icon: Icons.photo_library) → 
      _pickAndLinkPhoto(code, ImageSource.gallery),
    IconButton(icon: Icons.camera_alt) → 
      _pickAndLinkPhoto(code, ImageSource.camera),
    IconButton(icon: Icons.delete) → 
      _confirmAndRemovePhoto(code),
  ]
)
```

### 3. Importação CSV

#### Fluxo de Importação

```dart
// 1. Seleção de arquivo
FilePickerResult? result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['csv'],
);

// 2. Parsing
final bytes = await File(result.files.single.path!).readAsBytes();
final parsed = CsvImportService.parseCsvWithDetails(bytes);

// 3. Merge com dados existentes
barcodeManager.mergeDetails(parsed.detailsByCode);

// 4. Adicionar novos códigos (opcional)
for (var item in parsed.items) {
  barcodeManager.addBarcodeItem(item);
}

// 5. Upload para Firebase
await syncService.syncAllDetails();
```

#### Parsing CSV

**Detecção de Colunas**:
```dart
int idxOf(String name, int fallback) {
  final i = header.indexWhere((h) => 
    h.toLowerCase().contains(name.toLowerCase())
  );
  return i == -1 ? fallback : i;
}

final patrimonioIndex = idxOf('Patrimônio', 6);
final descIndex = idxOf('Descrição', 8);
final locIndex = idxOf('Localização', 9);
// ... etc
```

**Extração de Dados**:
```dart
for (int i = 1; i < rows.length; i++) {
  final row = rows[i];
  final code = row[patrimonioIndex].toString().trim();
  
  if (code.isEmpty) continue;
  
  final details = AssetDetails(
    item: row[itemIndex].toString(),
    oldCode: row[oldIndex].toString(),
    description: row[descIndex].toString(),
    location: row[locIndex].toString(),
    acquisitionValue: row[valIndex].toString(),
  );
  
  detailsByCode[code] = details;
}
```

### 4. Sincronização Firebase

#### Upload de Item

```dart
Future<void> syncItem(BarcodeItem item) async {
  await _itemsCollection.doc(item.code).set({
    'code': item.code,
    'status': item.status.index,
    'description': item.description ?? '',
    'photoPath': _photoByCode[item.code] ?? '',
    'timestamp': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}
```

#### Download Inicial

```dart
Future<void> loadItems() async {
  final snapshot = await _itemsCollection.get();
  
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final item = BarcodeItem(
      code: data['code'],
      status: BarcodeStatus.values[data['status'] ?? 0],
    );
    
    barcodeManager.addBarcodeItemSilent(item);
    
    if (data['photoPath'] != null && data['photoPath'].isNotEmpty) {
      barcodeManager._photoByCode[item.code] = data['photoPath'];
    }
  }
}
```

#### Listener em Tempo Real

```dart
Stream<void> listenToChanges() {
  return _itemsCollection.snapshots().asyncMap((snapshot) async {
    for (var change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.added ||
          change.type == DocumentChangeType.modified) {
        
        final data = change.doc.data()!;
        final item = BarcodeItem(
          code: data['code'],
          status: BarcodeStatus.values[data['status']],
        );
        
        // Atualizar localmente sem notificar (para evitar loop)
        if (!barcodeManager.containsBarcode(item.code)) {
          barcodeManager.addBarcodeItemSilent(item);
        } else {
          barcodeManager.updateBarcodeStatusSilent(
            item.code, 
            item.status
          );
        }
      }
      
      if (change.type == DocumentChangeType.removed) {
        barcodeManager.removeBarcodeSilent(change.doc.id);
      }
    }
  });
}
```

---

## 🔄 Fluxo de Dados

### Diagrama de Fluxo Completo

```
┌──────────────────────────────────────────────────────────┐
│                     Usuário Escaneia                      │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│         Scanner: Verificação Tripla (3x, 200ms)          │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│            Código Confirmado: _processConfirmedCode       │
└────────────────────────┬─────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │                               │
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│  Código Novo    │           │  Código Existe  │
└────────┬────────┘           └────────┬────────┘
         │                             │
         ▼                             ▼
┌─────────────────┐           ┌─────────────────┐
│ Selecionar      │           │ Mostrar Status  │
│ Status          │           │ e Descrição     │
└────────┬────────┘           └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Adicionar       │
│ Descrição?      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Adicionar Foto? │
│ (Skip/Galeria/  │
│  Câmera)        │
└────────┬────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────┐
│        BarcodeManager.addBarcodeItem(item)               │
│             - Adiciona à lista local                     │
│             - Salva em JSON                              │
│             - notifyListeners()                          │
│             - Chama syncService.syncItem()               │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│        SyncService.syncItem(item)                        │
│          - Upload para Firestore                         │
│          - items/{code}                                  │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│              Firebase Firestore                          │
│       (Armazena e sincroniza entre dispositivos)         │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│        SyncService.listenToChanges()                     │
│          - Detecta mudanças remotas                      │
│          - Atualiza BarcodeManager (silent)              │
└────────────────────────┬─────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│                    UI Atualizada                         │
│        (ChangeNotifier dispara rebuild)                  │
└──────────────────────────────────────────────────────────┘
```

---

## 🔒 Segurança

### Proteção de Credenciais

**❌ ANTES** (credenciais expostas):
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'AIzaSyCVOMmidqPOK4rjstwHKa0nzS-d0JsVJIc', // EXPOSTO!
  appId: '1:1016473191297:android:9cfc37dda5db30a1eade80',
  // ...
);
```

**✅ DEPOIS** (variáveis de ambiente):
```dart
static FirebaseOptions get android => FirebaseOptions(
  apiKey: _envOrThrow('FIREBASE_ANDROID_API_KEY'),
  appId: _envOrThrow('FIREBASE_ANDROID_APP_ID'),
  // ...
);

static String _envOrThrow(String key) {
  final value = dotenv.env[key];
  if (value == null || value.isEmpty) {
    throw StateError('Variável de ambiente "$key" não encontrada');
  }
  return value;
}
```

### Validação de Variáveis

O método `_envOrThrow` garante que:
- ✅ Todas as variáveis obrigatórias estejam presentes
- ✅ Nenhuma variável esteja vazia
- ✅ Erro claro em caso de configuração incorreta

### Gitignore

```gitignore
# Credentials
/.env

# Build outputs
/build/
```

---

## 🎨 Sistema de Status

### Enumeração de Status

```dart
enum BarcodeStatus {
  none(
    'Sem status', 
    Colors.grey
  ),
  
  found(
    'Encontrado sem nenhuma pendência', 
    Colors.green
  ),
  
  foundNotRelated(
    'Bens encontrados e não relacionados', 
    Color(0xFFB19CD9)
  ),
  
  notRegistered(
    'Bens permanentes sem identificação', 
    Colors.lightBlue
  ),
  
  damaged(
    'Bens danificados', 
    Colors.orange
  ),
  
  notFound(
    'Bens não encontrados', 
    Colors.red
  );

  final String label;
  final Color color;
  const BarcodeStatus(this.label, this.color);
}
```

### Uso Visual

**Lista de Códigos**:
```dart
Card(
  color: item.status.color.withOpacity(0.1), // Fundo sutil
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: item.status.color,    // Indicador colorido
      radius: 12,
    ),
    title: Text(item.code),
    subtitle: Text(item.status.label),       // Nome do status
  ),
)
```

**Estatísticas**:
```dart
Map<BarcodeStatus, int> getStatistics() {
  final stats = <BarcodeStatus, int>{};
  for (var item in barcodes) {
    stats[item.status] = (stats[item.status] ?? 0) + 1;
  }
  return stats;
}
```

---

## 📦 Exportação de Dados

### Geração do ZIP

```dart
static Future<void> exportBarcodes(
  List<BarcodeItem> barcodes, {
  required BarcodeManager manager,
}) async {
  // 1. Criar conteúdo TXT
  final content = StringBuffer();
  content.writeln('Lista de Códigos de Barras');
  content.writeln('Data: ${DateTime.now()}');
  content.writeln('Total: ${barcodes.length} códigos\n');
  
  for (var item in barcodes) {
    content.writeln('[${index}] ${item.code}');
    content.writeln('    Status: ${item.status.label}');
    content.writeln('    Data: ${item.timestamp}\n');
  }
  
  // 2. Criar diretório temporário
  final tempDir = await getTemporaryDirectory();
  final exportDir = Directory('${tempDir.path}/exportacao_$timestamp');
  await exportDir.create(recursive: true);
  
  // 3. Salvar TXT
  final txtFile = File('${exportDir.path}/codigos_barras.txt');
  await txtFile.writeAsString(content.toString());
  
  // 4. Copiar fotos
  for (var item in barcodes) {
    final photoPath = manager.getPhotoPath(item.code);
    if (photoPath != null && File(photoPath).existsSync()) {
      final ext = _safeExtension(photoPath);
      final sanitized = _sanitizeFilename(item.code);
      final dest = File('${exportDir.path}/$sanitized$ext');
      await File(photoPath).copy(dest.path);
    }
  }
  
  // 5. Compactar
  final zipPath = '${tempDir.path}/exportacao_$timestamp.zip';
  final encoder = ZipFileEncoder();
  encoder.create(zipPath);
  encoder.addDirectory(exportDir);
  encoder.close();
  
  // 6. Compartilhar
  await Share.shareXFiles([XFile(zipPath)]);
}
```

### Sanitização de Nomes

```dart
static String _sanitizeFilename(String input) {
  return input
    .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')  // Caracteres inválidos
    .replaceAll(RegExp(r'\s+'), '_')           // Espaços
    .trim();
}
```

---

## 🧪 Desenvolvimento

### Executar em Modo Debug

```bash
flutter run
```

### Build de Produção

**Android**:
```bash
flutter build apk --release
flutter build appbundle --release
```

**iOS**:
```bash
flutter build ios --release
```

### Testes

```bash
# Executar todos os testes
flutter test

# Executar com cobertura
flutter test --coverage
```

### Análise de Código

```bash
# Verificar problemas
flutter analyze

# Formatar código
flutter format lib/
```

---

## 🐛 Troubleshooting

### Problemas Comuns

#### 1. Erro: "Variável de ambiente não encontrada"

**Causa**: Arquivo `.env` não existe ou está mal configurado.

**Solução**:
```bash
# Verificar se .env existe
ls -la .env

# Copiar do template
cp .env.example .env

# Editar com suas credenciais
nano .env
```

#### 2. Escaneamento não funciona

**Causa**: Permissões de câmera não concedidas.

**Solução**:
- Android: Verificar `AndroidManifest.xml`
- iOS: Verificar `Info.plist`
- Desinstalar e reinstalar o app
- Conceder permissões manualmente nas configurações

#### 3. Fotos não aparecem

**Causa**: Caminho de foto inválido ou arquivo deletado.

**Solução**:
```dart
// Verificar se arquivo existe
final photoPath = manager.getPhotoPath(code);
if (photoPath != null && File(photoPath).existsSync()) {
  // OK
} else {
  // Remover referência inválida
  manager.removePhotoForCode(code);
}
```

#### 4. Sincronização não funciona

**Causa**: Regras do Firestore bloqueando acesso.

**Solução**:
```javascript
// Firestore Rules (modo desenvolvimento)
allow read, write: if true;

// Firestore Rules (produção)
allow read, write: if request.auth != null;
```

#### 5. Importação CSV falha

**Causa**: Encoding incorreto ou formato inesperado.

**Solução**:
- Salvar CSV com encoding UTF-8
- Verificar se delimitador é vírgula
- Verificar se cabeçalho contém "Patrimônio"

---

## 📝 Boas Práticas

### 1. Sempre use métodos silent para sync

```dart
// ❌ ERRADO - Cria loop infinito
manager.addBarcodeItem(item);  // Notifica → Sync → Listener → Notifica...

// ✅ CORRETO - Ao receber do Firebase
manager.addBarcodeItemSilent(item);  // Não notifica
```

### 2. Valide dados antes de processar

```dart
if (code.isEmpty) return;
if (!File(photoPath).existsSync()) {
  photoPath = null;
}
```

### 3. Use try-catch em operações assíncronas

```dart
try {
  await syncService.syncItem(item);
} catch (e) {
  print('Erro ao sincronizar: $e');
  // Tentar novamente ou notificar usuário
}
```

### 4. Limpe recursos no dispose

```dart
@override
void dispose() {
  _controller.dispose();
  manager.removeListener(_onDataChanged);
  super.dispose();
}
```

---

## 📊 Métricas e Performance

### Otimizações Implementadas

1. **Lazy Loading**: Fotos carregadas sob demanda
2. **Debouncing**: Evita múltiplas leituras em < 200ms
3. **Silent Updates**: Previne loops de sincronização
4. **Batch Operations**: CSV import processa em lote
5. **Image Compression**: Fotos limitadas a 1920x1080, qualidade 85%

### Limites Recomendados

- **Códigos por projeto**: < 10,000
- **Tamanho de foto**: < 5MB cada
- **Total de fotos**: < 500MB
- **Frequência de sync**: Batch a cada 30s

---

## 🚀 Roadmap Futuro

### Funcionalidades Planejadas

- [ ] Autenticação de usuários
- [ ] Relatórios em PDF
- [ ] Gráficos e dashboards
- [ ] Modo offline completo
- [ ] Sincronização otimizada (batch)
- [ ] Busca e filtros avançados
- [ ] Backup automático
- [ ] Suporte a múltiplos projetos
- [ ] Assinatura digital nos relatórios
- [ ] Integração com impressoras térmicas

---

## 👥 Contribuindo

Este é um projeto privado. Para contribuir:

1. Crie uma branch para sua feature
2. Faça commit das mudanças
3. Abra um Pull Request
4. Aguarde revisão

---

## 📄 Licença

Este projeto é privado e de uso interno.

---

## 📞 Suporte

Para dúvidas ou problemas, entre em contato com a equipe de desenvolvimento.

---

**Desenvolvido com ❤️ usando Flutter**