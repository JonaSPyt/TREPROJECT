import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/barcode_scanner_screen.dart';
import 'pages/departamentos_screen.dart';
import 'pages/tombamentos_sem_departamento_screen.dart';
import 'utils/patrimonio_manager.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';

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
      title: 'PatriTRE',
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
class HomeScreen extends StatefulWidget {
  final BarcodeManager barcodeManager;
  final ApiService apiService;

  const HomeScreen({
    super.key, 
    required this.barcodeManager,
    required this.apiService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnected = false;
  
  @override
  void initState() {
    super.initState();
    _checkConnection();
    widget.barcodeManager.addListener(_onDataChanged);
  }
  
  @override
  void dispose() {
    widget.barcodeManager.removeListener(_onDataChanged);
    super.dispose();
  }
  
  void _onDataChanged() {
    setState(() {});
  }
  
  Future<void> _checkConnection() async {
    final connected = await widget.apiService.checkConnection();
    if (mounted) {
      setState(() => _isConnected = connected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.barcodeManager.barcodes.length;
    
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header com gradiente
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo e status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.inventory_2_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          // Status de conexão
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isConnected 
                                  ? Colors.green.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isConnected 
                                    ? Colors.green.withOpacity(0.5)
                                    : Colors.red.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _isConnected ? Colors.green : Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isConnected ? 'Online' : 'Offline',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Título
                      const Text(
                        'PatriTRE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sistema de Inventário Patrimonial',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Card de estatísticas
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.qr_code_scanner_rounded,
                                value: itemCount.toString(),
                                label: 'Itens',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.check_circle_outline,
                                value: widget.barcodeManager.barcodes
                                    .where((b) => b.status.index == 1)
                                    .length
                                    .toString(),
                                label: 'Encontrados',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.search_off_rounded,
                                value: widget.barcodeManager.barcodes
                                    .where((b) => b.status.index == 5)
                                    .length
                                    .toString(),
                                label: 'Não encontrados',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Conteúdo principal
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ações Rápidas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Card Scanner
                    _buildActionCard(
                      context,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scanner',
                      subtitle: 'Escanear código de barras',
                      gradient: AppColors.primaryGradient,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ScannerScreen(
                              barcodeManager: widget.barcodeManager,
                              apiService: widget.apiService,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Card Departamentos (no lugar da lista)
                    _buildActionCard(
                      context,
                      icon: Icons.meeting_room_rounded,
                      title: 'Departamentos',
                      subtitle: 'Organizar patrimônios por sala',
                      gradient: AppColors.secondaryGradient,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DepartamentosScreen(
                              barcodeManager: widget.barcodeManager,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) {
                            print('🔄 Voltando dos departamentos - atualizando tela principal (${widget.barcodeManager.barcodes.length} itens)');
                            setState(() {});
                          }
                        });
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Card Tombamentos sem Departamento
                    _buildActionCard(
                      context,
                      icon: Icons.folder_off_rounded,
                      title: 'Sem Departamento',
                      subtitle: 'Tombamentos não vinculados',
                      gradient: const LinearGradient(
                        colors: [Color(0xFF64748B), Color(0xFF475569)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TombamentosSemDepartamentoScreen(
                              barcodeManager: widget.barcodeManager,
                            ),
                          ),
                        ).then((_) => setState(() {}));
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Seção de dicas
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Dica',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Aponte a câmera para o código de barras e mantenha firme por 3 leituras consecutivas.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (gradient as LinearGradient).colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.8),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
