# 🚀 Quick Start - TreProject com API Interna

## ⚡ Início Rápido (5 minutos)

### 1️⃣ Configurar Servidor (Terminal 1)

```bash
# Instalar dependências
npm install

# Editar IP no server.js (linha 6)
# const HOST = '192.168.201.126'; // Altere para seu IP

# Iniciar servidor
npm start
```

Você verá:
```
╔════════════════════════════════════════════════════╗
║  🚀 API de Tombamentos rodando!                    ║
║  📍 URL: http://192.168.201.126:3000               ║
╚════════════════════════════════════════════════════╝
```

---

### 2️⃣ Configurar App Flutter (Terminal 2)

```bash
# Configurar .env
cp .env.example .env
nano .env  # Edite API_BASE_URL se necessário

# Instalar dependências
flutter pub get

# Executar app
flutter run
```

---

## 🧪 Testar API

### No navegador:
```
http://192.168.201.126:3000/health
```

Resposta esperada:
```json
{
  "status": "ok",
  "timestamp": "2025-11-14T...",
  "tombamentos": 0,
  "detalhes": 0
}
```

### Com curl:
```bash
# Health check
curl http://192.168.201.126:3000/health

# Criar tombamento
curl -X POST http://192.168.201.126:3000/tombamentos \
  -H "Content-Type: application/json" \
  -d '{"code":"12345","status":1}'

# Listar tombamentos
curl http://192.168.201.126:3000/tombamentos
```

---

## 📱 Usar o App

1. **Escanear código**: 
   - Toque em "Scanner"
   - Aponte para código de barras
   - Confirme 3 vezes para adicionar

2. **Ver lista**: 
   - Toque em "Outra Tela"
   - Veja todos os códigos escaneados

3. **Importar CSV**:
   - Toque no botão "+" flutuante
   - Selecione arquivo CSV
   - Dados serão importados

4. **Exportar dados**:
   - Na lista, toque no ícone de compartilhar
   - ZIP será gerado com dados e fotos

---

## 🔍 Verificar Sincronização

### Logs do servidor:
```
📤 Enviando 0 tombamentos
➕ Tombamento criado: 12345
```

### Logs do app (Flutter):
```
🔍 Verificando conexão com API interna...
✅ Conexão com API estabelecida!
🌐 Iniciando carregamento da API interna...
✅ Carregamento inicial concluído!
```

---

## 🛠️ Estrutura Mínima

```
TREPROJECT/
├── server.js         ← API Node.js
├── package.json      ← Dependências Node
├── .env             ← Configuração (API_BASE_URL)
├── lib/
│   ├── main.dart    ← App Flutter
│   └── services/
│       └── api_service.dart  ← Cliente HTTP
└── data.json        ← Dados (criado automaticamente)
```

---

## ⚠️ Troubleshooting Rápido

### ❌ App não conecta
```bash
# Verifique se servidor está rodando
curl http://192.168.201.126:3000/health

# Verifique IP no .env
cat .env | grep API_BASE_URL

# Verifique se está no WiFi correto
```

### ❌ Porta 3000 em uso
```bash
# Linux/Mac
lsof -i :3000
kill -9 <PID>

# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Ou altere porta no server.js:
# const PORT = 3001;
```

### ❌ Permissão negada
```bash
# Execute com sudo (Linux/Mac)
sudo npm start

# Ou use porta > 1024
const PORT = 8080;
```

---

## 📖 Documentação Completa

- `README.md` - Documentação geral
- `API_DOCUMENTATION.md` - Spec completa da API
- `SERVER_README.md` - Guia do servidor
- `CHANGELOG.md` - Resumo das mudanças

---

## 🎯 Próximo Passo

Após testar localmente:
1. Configure IP fixo no servidor
2. Configure DNS interno (ex: `tombamentos.empresa.local`)
3. Adicione autenticação
4. Configure backup automático

---

**Pronto! Em 5 minutos você tem:**
- ✅ API rodando
- ✅ App conectado
- ✅ Sincronização funcionando
- ✅ Modo offline habilitado

🎉 **Bom trabalho!**
