# API Server para TreProject

## Instalação

```bash
npm install
```

## Configuração

1. Edite o arquivo `server.js` e altere o `HOST` para o IP do servidor na sua rede:
   ```javascript
   const HOST = '192.168.201.126'; // Seu IP aqui
   ```

2. Verifique se a porta 3000 está disponível. Se não, altere o `PORT`:
   ```javascript
   const PORT = 3000; // Altere se necessário
   ```

## Executar o Servidor

### Modo normal:
```bash
npm start
```

### Modo desenvolvimento (reinicia automaticamente ao alterar código):
```bash
npm run dev
```

## Endpoints Disponíveis

Veja `API_DOCUMENTATION.md` para detalhes completos de todos os endpoints.

### Principais endpoints:
- `GET /health` - Health check
- `GET /tombamentos` - Lista todos os tombamentos
- `POST /tombamentos` - Cria/atualiza tombamento
- `GET /detalhes` - Lista todos os detalhes
- `POST /detalhes/batch` - Importa detalhes em lote

## Persistência de Dados

Os dados são salvos automaticamente no arquivo `data.json` na mesma pasta do servidor. 

Se você reiniciar o servidor, os dados serão carregados automaticamente.

## Testando a API

### Com curl:
```bash
# Health check
curl http://192.168.201.126:3000/health

# Criar tombamento
curl -X POST http://192.168.201.126:3000/tombamentos \
  -H "Content-Type: application/json" \
  -d '{"code":"123456","status":1}'

# Listar tombamentos
curl http://192.168.201.126:3000/tombamentos
```

### Com o navegador:
Abra: `http://192.168.201.126:3000/health`

## Logs

O servidor exibe logs coloridos no console:
- ✅ Sucesso
- ❌ Erro
- 📤 Enviando dados
- 📦 Batch operations
- 🔄 Atualização
- ➕ Criação
- 🗑️ Remoção

## Problemas Comuns

### Porta já em uso
Se a porta 3000 já estiver em uso:
```bash
# Linux/Mac - Encontrar processo
lsof -i :3000

# Windows - Encontrar processo
netstat -ano | findstr :3000

# Matar processo (substitua PID pelo número encontrado)
kill -9 PID
```

### Erro de permissão no IP
Execute como administrador ou use `0.0.0.0` como HOST (aceita conexões de qualquer IP).

### Firewall bloqueando
Certifique-se de que a porta 3000 está aberta no firewall do servidor.

## Backup

Para fazer backup dos dados:
```bash
cp data.json data.backup.json
```

## Restaurar Backup

```bash
cp data.backup.json data.json
```

## Limpar Dados

Para limpar todos os dados:
```bash
rm data.json
# Ou via API:
curl -X DELETE http://192.168.201.126:3000/tombamentos/all
```
