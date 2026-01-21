const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;
const HOST = '0.0.0.0'; // Aceita conexões de qualquer IP/rede (WiFi e cabo)

// Middleware
app.use(cors()); // Permite requisições do app Flutter
app.use(express.json({ limit: '50mb' })); // Parse JSON bodies

// Arquivo para persistir dados (opcional)
const DATA_FILE = path.join(__dirname, 'data.json');

// Estrutura de dados em memória
let data = {
  tombamentos: [],
  detalhes: []
};

// Carrega dados do arquivo se existir
function loadData() {
  try {
    if (fs.existsSync(DATA_FILE)) {
      const fileContent = fs.readFileSync(DATA_FILE, 'utf8');
      data = JSON.parse(fileContent);
      console.log('✅ Dados carregados do arquivo');
      console.log(`📦 Tombamentos: ${data.tombamentos.length}`);
      console.log(`📋 Detalhes: ${data.detalhes.length}`);
    }
  } catch (error) {
    console.error('❌ Erro ao carregar dados:', error);
  }
}

// Salva dados no arquivo
function saveData() {
  try {
    fs.writeFileSync(DATA_FILE, JSON.stringify(data, null, 2), 'utf8');
    console.log('💾 Dados salvos no arquivo');
  } catch (error) {
    console.error('❌ Erro ao salvar dados:', error);
  }
}

// Middleware de log
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// ============================================
// ROTAS
// ============================================

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date().toISOString(),
    tombamentos: data.tombamentos.length,
    detalhes: data.detalhes.length
  });
});

// Listar todos os tombamentos
app.get('/tombamentos', (req, res) => {
  console.log(`📤 Enviando ${data.tombamentos.length} tombamentos`);
  res.json(data.tombamentos);
});

// Obter tombamento específico
app.get('/tombamentos/:code', (req, res) => {
  const { code } = req.params;
  const tombamento = data.tombamentos.find(t => t.code === code);
  
  if (tombamento) {
    res.json(tombamento);
  } else {
    res.status(404).json({ error: 'Tombamento não encontrado' });
  }
});

// Criar ou atualizar tombamento
app.post('/tombamentos', (req, res) => {
  const { code, status } = req.body;
  
  if (!code) {
    return res.status(400).json({ error: 'Código é obrigatório' });
  }
  
  const index = data.tombamentos.findIndex(t => t.code === code);
  
  if (index >= 0) {
    // Atualiza existente
    data.tombamentos[index] = { code, status: status || 0 };
    console.log(`🔄 Tombamento atualizado: ${code}`);
  } else {
    // Cria novo
    data.tombamentos.push({ code, status: status || 0 });
    console.log(`➕ Tombamento criado: ${code}`);
  }
  
  saveData();
  res.status(201).json({ code, status: status || 0 });
});

// Atualizar tombamento
app.put('/tombamentos/:code', (req, res) => {
  const { code } = req.params;
  const { status } = req.body;
  const index = data.tombamentos.findIndex(t => t.code === code);
  
  if (index >= 0) {
    data.tombamentos[index].status = status;
    saveData();
    console.log(`✏️  Tombamento ${code} atualizado - Status: ${status}`);
    res.json(data.tombamentos[index]);
  } else {
    console.log(`❌ Tombamento ${code} não encontrado`);
    res.status(404).json({ error: 'Tombamento não encontrado' });
  }
});

// Remover tombamento específico
app.delete('/tombamentos/:code', (req, res) => {
  const { code } = req.params;
  const initialLength = data.tombamentos.length;
  
  data.tombamentos = data.tombamentos.filter(t => t.code !== code);
  
  if (data.tombamentos.length < initialLength) {
    saveData();
    console.log(`🗑️  Tombamento ${code} removido`);
    res.status(204).send();
  } else {
    console.log(`❌ Tombamento ${code} não encontrado`);
    res.status(404).json({ error: 'Tombamento não encontrado' });
  }
});

// Remover todos os tombamentos
app.delete('/tombamentos/all', (req, res) => {
  const count = data.tombamentos.length;
  data.tombamentos = [];
  saveData();
  console.log(`🗑️  ${count} tombamentos removidos`);
  res.status(204).send();
});

// Listar todos os detalhes
app.get('/detalhes', (req, res) => {
  console.log(`📤 Enviando ${data.detalhes.length} detalhes`);
  res.json(data.detalhes);
});

// Obter detalhes de um código específico
app.get('/detalhes/:code', (req, res) => {
  const { code } = req.params;
  const detalhe = data.detalhes.find(d => d.code === code);
  
  if (detalhe) {
    res.json(detalhe);
  } else {
    res.status(404).json({ error: 'Detalhes não encontrados' });
  }
});

// Criar ou atualizar detalhe individual
app.post('/detalhes', (req, res) => {
  const detalhe = req.body;
  
  if (!detalhe.code) {
    return res.status(400).json({ error: 'Código é obrigatório' });
  }
  
  const index = data.detalhes.findIndex(d => d.code === detalhe.code);
  
  if (index >= 0) {
    data.detalhes[index] = detalhe;
    console.log(`🔄 Detalhe atualizado: ${detalhe.code}`);
  } else {
    data.detalhes.push(detalhe);
    console.log(`➕ Detalhe criado: ${detalhe.code}`);
  }
  
  saveData();
  res.status(201).json(detalhe);
});

// Sincronizar detalhes em lote
app.post('/detalhes/batch', (req, res) => {
  const { detalhes: newDetalhes } = req.body;
  
  if (!newDetalhes || !Array.isArray(newDetalhes)) {
    return res.status(400).json({ error: 'Array de detalhes é obrigatório' });
  }
  
  let created = 0;
  let updated = 0;
  
  newDetalhes.forEach(detalhe => {
    const index = data.detalhes.findIndex(d => d.code === detalhe.code);
    if (index >= 0) {
      data.detalhes[index] = detalhe;
      updated++;
    } else {
      data.detalhes.push(detalhe);
      created++;
    }
  });
  
  saveData();
  console.log(`📦 Batch: ${created} criados, ${updated} atualizados`);
  res.status(201).json({ 
    count: newDetalhes.length,
    created,
    updated
  });
});

// Estatísticas
app.get('/stats', (req, res) => {
  const statusCount = {};
  data.tombamentos.forEach(t => {
    statusCount[t.status] = (statusCount[t.status] || 0) + 1;
  });
  
  res.json({
    totalTombamentos: data.tombamentos.length,
    totalDetalhes: data.detalhes.length,
    statusDistribution: statusCount,
    timestamp: new Date().toISOString()
  });
});

// Tratamento de rota não encontrada
app.use((req, res) => {
  res.status(404).json({ 
    error: 'Rota não encontrada',
    path: req.path,
    method: req.method
  });
});

// Tratamento de erros
app.use((err, req, res, next) => {
  console.error('❌ Erro:', err);
  res.status(500).json({ 
    error: 'Erro interno do servidor',
    message: err.message
  });
});

// ============================================
// INICIALIZAÇÃO
// ============================================

// Carrega dados ao iniciar
loadData();

// Inicia servidor
app.listen(PORT, HOST, () => {
  console.log('╔════════════════════════════════════════════════════╗');
  console.log('║  🚀 API de Tombamentos rodando!                    ║');
  console.log('╠════════════════════════════════════════════════════╣');
  console.log(`║  📍 Host: ${HOST}:${PORT} (todas as interfaces)     ║`);
  console.log(`║  🌐 Acesse via: http://10.7.100.114:${PORT}          ║`);
  console.log(`║  📦 Tombamentos: ${data.tombamentos.length.toString().padEnd(31)}║`);
  console.log(`║  📋 Detalhes: ${data.detalhes.length.toString().padEnd(34)}║`);
  console.log('╠════════════════════════════════════════════════════╣');
  console.log('║  Endpoints disponíveis:                            ║');
  console.log('║  GET    /health                                    ║');
  console.log('║  GET    /stats                                     ║');
  console.log('║  GET    /tombamentos                               ║');
  console.log('║  POST   /tombamentos                               ║');
  console.log('║  PUT    /tombamentos/:code                         ║');
  console.log('║  DELETE /tombamentos/:code                         ║');
  console.log('║  DELETE /tombamentos/all                           ║');
  console.log('║  GET    /detalhes                                  ║');
  console.log('║  POST   /detalhes                                  ║');
  console.log('║  POST   /detalhes/batch                            ║');
  console.log('╚════════════════════════════════════════════════════╝');
});

// Salva dados antes de fechar
process.on('SIGINT', () => {
  console.log('\n💾 Salvando dados antes de fechar...');
  saveData();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n💾 Salvando dados antes de fechar...');
  saveData();
  process.exit(0);
});
