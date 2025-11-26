# API Interna - Documentação

## Visão Geral

O aplicativo agora está configurado para se comunicar com uma API interna que funciona apenas no WiFi da empresa. A API deve estar rodando em `http://192.168.201.126:3000`.

## Configuração

A URL da API é definida no arquivo `.env`:

```env
API_BASE_URL=http://192.168.201.126:3000
```

## Endpoints Necessários

A API deve implementar os seguintes endpoints:

### 1. Health Check (Opcional, mas recomendado)
```
GET /health
```
**Resposta esperada:**
- Status: 200 OK
- Body: Qualquer conteúdo (pode ser vazio ou um JSON simples)

**Uso:** Verificar se a API está acessível antes de iniciar operações.

---

### 2. Listar Tombamentos
```
GET /tombamentos
```
**Resposta esperada:**
```json
[
  {
    "code": "123456",
    "status": 1
  },
  {
    "code": "789012",
    "status": 2
  }
]
```

**Campos:**
- `code` (string): Código do patrimônio/tombamento
- `status` (integer): Status do patrimônio (0-5, conforme enum abaixo)

**Status disponíveis:**
```
0 = Sem status (none)
1 = Encontrado sem nenhuma pendência (found)
2 = Bens encontrados e não relacionados (foundNotRelated)
3 = Bens permanentes sem identificação (notRegistered)
4 = Bens danificados (damaged)
5 = Bens não encontrados (notFound)
```

---

### 3. Criar Tombamento
```
POST /tombamentos
Content-Type: application/json
```

**Body:**
```json
{
  "code": "123456",
  "status": 1
}
```

**Resposta esperada:**
- Status: 200 OK ou 201 Created

---

### 4. Atualizar Tombamento
```
PUT /tombamentos/:code
Content-Type: application/json
```

**Body:**
```json
{
  "code": "123456",
  "status": 2
}
```

**Resposta esperada:**
- Status: 200 OK

---

### 5. Remover Tombamento
```
DELETE /tombamentos/:code
```

**Resposta esperada:**
- Status: 200 OK ou 204 No Content

---

### 6. Listar Detalhes
```
GET /detalhes
```

**Resposta esperada:**
```json
[
  {
    "code": "123456",
    "item": "Cadeira",
    "oldCode": "OLD123",
    "descricao": "Cadeira de escritório ergonômica",
    "localizacao": "Sala 301",
    "valorAquisicao": "R$ 500,00"
  }
]
```

**Campos:**
- `code` (string): Código do patrimônio
- `item` (string, opcional): Nome/tipo do item
- `oldCode` (string, opcional): Código antigo
- `descricao` (string, opcional): Descrição do item
- `localizacao` (string, opcional): Localização física
- `valorAquisicao` (string, opcional): Valor de aquisição

---

### 7. Sincronizar Detalhes em Lote
```
POST /detalhes/batch
Content-Type: application/json
```

**Body:**
```json
{
  "detalhes": [
    {
      "code": "123456",
      "item": "Cadeira",
      "oldCode": "OLD123",
      "descricao": "Cadeira de escritório ergonômica",
      "localizacao": "Sala 301",
      "valorAquisicao": "R$ 500,00"
    },
    {
      "code": "789012",
      "item": "Mesa",
      "oldCode": "OLD456",
      "descricao": "Mesa de escritório",
      "localizacao": "Sala 302",
      "valorAquisicao": "R$ 800,00"
    }
  ]
}
```

**Resposta esperada:**
- Status: 200 OK ou 201 Created

---

### 8. Limpar Todos os Tombamentos (Opcional)
```
DELETE /tombamentos/all
```

**Resposta esperada:**
- Status: 200 OK ou 204 No Content

---

## Comportamento do App

### Inicialização
1. O app verifica conexão com a API (`/health`)
2. Se conectado, carrega tombamentos e detalhes
3. Se desconectado, funciona offline com dados locais

### Sincronização
- **Adicionar/Escanear código:** Envia POST para `/tombamentos`
- **Atualizar status:** Envia PUT para `/tombamentos/:code`
- **Remover código:** Envia DELETE para `/tombamentos/:code`
- **Importar CSV:** Envia POST para `/detalhes/batch`

### Modo Offline
Se a API não estiver acessível:
- O app continua funcionando normalmente
- Dados são salvos localmente em JSON
- Sincronização ocorrerá quando a conexão for restabelecida (requer restart do app)

---

## Timeouts

Todos os requests têm timeout de:
- **GET requests:** 10 segundos
- **POST/PUT/DELETE:** 10 segundos
- **Batch operations:** 30 segundos
- **Health check:** 5 segundos

---

## Tratamento de Erros

O app exibe mensagens no console quando:
- ❌ Não consegue conectar com a API
- ❌ Recebe status code de erro (não 200/201/204)
- ⚠️ Opera em modo offline

O usuário sempre verá mensagens amigáveis via SnackBar quando houver problemas.

---

## Exemplo de Servidor Node.js Simples

Aqui está um exemplo básico de como implementar a API usando Node.js + Express:

```javascript
const express = require('express');
const app = express();
app.use(express.json());

let tombamentos = [];
let detalhes = [];

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Listar tombamentos
app.get('/tombamentos', (req, res) => {
  res.json(tombamentos);
});

// Criar tombamento
app.post('/tombamentos', (req, res) => {
  const { code, status } = req.body;
  const index = tombamentos.findIndex(t => t.code === code);
  
  if (index >= 0) {
    tombamentos[index] = { code, status };
  } else {
    tombamentos.push({ code, status });
  }
  
  res.status(201).json({ code, status });
});

// Atualizar tombamento
app.put('/tombamentos/:code', (req, res) => {
  const { code } = req.params;
  const { status } = req.body;
  const index = tombamentos.findIndex(t => t.code === code);
  
  if (index >= 0) {
    tombamentos[index].status = status;
    res.json(tombamentos[index]);
  } else {
    res.status(404).json({ error: 'Not found' });
  }
});

// Remover tombamento
app.delete('/tombamentos/:code', (req, res) => {
  const { code } = req.params;
  tombamentos = tombamentos.filter(t => t.code !== code);
  res.status(204).send();
});

// Listar detalhes
app.get('/detalhes', (req, res) => {
  res.json(detalhes);
});

// Sincronizar detalhes em lote
app.post('/detalhes/batch', (req, res) => {
  const { detalhes: newDetalhes } = req.body;
  
  newDetalhes.forEach(detalhe => {
    const index = detalhes.findIndex(d => d.code === detalhe.code);
    if (index >= 0) {
      detalhes[index] = detalhe;
    } else {
      detalhes.push(detalhe);
    }
  });
  
  res.status(201).json({ count: newDetalhes.length });
});

// Limpar todos
app.delete('/tombamentos/all', (req, res) => {
  tombamentos = [];
  res.status(204).send();
});

app.listen(3000, '192.168.201.126', () => {
  console.log('API rodando em http://192.168.201.126:3000');
});
```

Para executar:
```bash
npm init -y
npm install express
node server.js
```

---

## Migração do Firebase

O código do Firebase foi mantido para compatibilidade futura. Se quiser remover completamente:

1. Remova as dependências no `pubspec.yaml`:
   - `firebase_core`
   - `cloud_firestore`

2. Remova imports no `main.dart`:
   - `import 'package:firebase_core/firebase_core.dart';`
   - `import 'firebase_options.dart';`
   - `import 'services/sync_service.dart';`

3. Remova a inicialização do Firebase no `main()`.

Porém, recomendo manter para poder alternar entre Firebase e API interna conforme necessário.
