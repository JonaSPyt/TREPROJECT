import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/barcode_manager.dart';

/// Serviço responsável pela comunicação com a API interna da empresa.
/// Gerencia todas as operações de sincronização de dados via HTTP.
class ApiService {
  final BarcodeManager barcodeManager;
  final String baseUrl;
  bool _isSyncing = false;

  ApiService({
    required this.barcodeManager,
    String? apiUrl,
  }) : baseUrl = apiUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://192.168.200.205:3000' {
    print('🔧 ApiService inicializado com URL: $baseUrl');
    print('🔧 API_BASE_URL do .env: ${dotenv.env['API_BASE_URL']}');
  }

  /// Cabeçalhos padrão para requisições JSON
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  /// Carrega todos os tombamentos (itens) da API
  Future<void> loadItems() async {
    try {
      final url = '$baseUrl/tombamentos';
      print('🌐 Carregando tombamentos da API: $url');
      print('🔍 Fazendo requisição GET...');
      
      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      print('📥 Resposta recebida - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('📦 Body da resposta: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Encontrados ${data.length} tombamentos na API');

        _isSyncing = true;
        
        // Cria um Set com os códigos que existem na API
        final Set<String> codigosNaApi = {};
        
        // Processa todos os itens da API
        for (final item in data) {
          // A API PostgreSQL retorna 'codigo' ao invés de 'code'
          final code = (item['codigo'] ?? item['code']) as String?;
          if (code == null || code.isEmpty) continue;
          
          codigosNaApi.add(code);

          final statusIndex = item['status'] as int? ?? 1;
          final status =
              statusIndex >= 0 && statusIndex < BarcodeStatus.values.length
                  ? BarcodeStatus.values[statusIndex]
                  : BarcodeStatus.found;

          final barcodeItem = BarcodeItem(code: code, status: status);
          barcodeManager.addBarcodeItemSilent(barcodeItem);
          print('  ➕ Processado: $code (status: ${status.label})');
          
          // Também adiciona os detalhes se existirem
          if (item['descricao'] != null) {
            final details = AssetDetails(
              code: code,
              descricao: item['descricao'] as String?,
              localizacao: item['localizacao'] as String?,
              oldCode: item['oldcode'] as String?,
              valorAquisicao: item['valor'] as String?,
              item: null,
            );
            barcodeManager.mergeDetailsSilent({code: details});
          }
          
          // Sempre atualiza/salva a foto (mesmo que seja null para remover foto antiga)
          if (item['foto'] != null && item['foto'] != '') {
            final fotoUrl = item['foto'] as String;
            print('  🔍 Foto bruta da API: $fotoUrl');
            // Converte URL relativa para absoluta
            final fotoCompleta = fotoUrl.startsWith('http') 
                ? fotoUrl 
                : '$baseUrl$fotoUrl';
            // Salva URL da foto
            await barcodeManager.setPhotoForCode(code, fotoCompleta);
            print('  ✅ Foto vinculada: $fotoCompleta');
          } else {
            // Remove foto se não existe mais na API
            final fotoAtual = barcodeManager.getPhotoPath(code);
            if (fotoAtual != null && fotoAtual.startsWith('http')) {
              await barcodeManager.removePhotoForCode(code);
              print('  🗑️  Foto removida: $code');
            }
          }
        }
        
        // Remove itens locais que não existem mais na API
        final codigosLocais = barcodeManager.barcodes.map((e) => e.code).toList();
        for (final codigoLocal in codigosLocais) {
          if (!codigosNaApi.contains(codigoLocal)) {
            barcodeManager.removeBarcodeSilent(codigoLocal);
            print('  🗑️  Removido localmente (não existe na API): $codigoLocal');
          }
        }
        
        _isSyncing = false;

        if (data.isNotEmpty) {
          print('✅ Tombamentos carregados com sucesso!');
        } else {
          print('ℹ️  Nenhum tombamento encontrado na API');
        }
      } else {
        print('❌ Erro ao carregar tombamentos: ${response.statusCode}');
        print('📄 Resposta: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro ao conectar com a API: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
    } finally {
      _isSyncing = false;
    }
  }

  /// Carrega detalhes dos patrimônios da API
  /// Nota: Os detalhes já vêm junto com os tombamentos no loadItems()
  /// Este método é mantido apenas para compatibilidade
  Future<void> loadDetails() async {
    print('ℹ️  loadDetails() - Os detalhes já foram carregados com os tombamentos');
  }

  /// Sincroniza um item para a API
  Future<void> syncItem(BarcodeItem item) async {
    if (_isSyncing) {
      print('⏸️  Sincronização em andamento, pulando...');
      return;
    }
    
    try {
      // Busca detalhes do item se existirem
      final details = barcodeManager.getDetails(item.code);
      
      final url = '$baseUrl/tombamentos';
      final body = json.encode({
        'codigo': item.code,  // API espera 'codigo', não 'code'
        'descricao': details?.descricao ?? 'Patrimônio ${item.code}',  // Campo obrigatório
        'localizacao': details?.localizacao,
        'oldcode': details?.oldCode,
        'valor': details?.valorAquisicao,
        'status': item.status.index,
      });
      
      print('📤 Sincronizando item: ${item.code} para API...');
      print('🔗 URL: $url');
      print('📦 Body: $body');
      
      final response = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      print('📥 Resposta - Status: ${response.statusCode}');
      print('📄 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Item ${item.code} sincronizado com sucesso!');
      } else if (response.statusCode == 409) {
        // Código já existe, vamos atualizar ao invés de criar
        print('⚠️  Item já existe, atualizando...');
        await updateItemByCode(item.code, item);
      } else {
        print('❌ Erro ao sincronizar item: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao sincronizar item: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
      print('🔧 URL base configurada: $baseUrl');
    }
  }

  /// Atualiza um item existente na API (por código)
  Future<void> updateItemByCode(String codigo, BarcodeItem item) async {
    if (_isSyncing) return;
    
    try {
      print('📤 Buscando ID do tombamento: $codigo...');
      
      // Primeiro, buscar o ID do tombamento pelo código
      final getResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$codigo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode != 200) {
        print('❌ Tombamento não encontrado: $codigo');
        return;
      }

      final tombamento = json.decode(utf8.decode(getResponse.bodyBytes));
      final id = tombamento['id'];
      
      print('📝 ID encontrado: $id, atualizando...');
      
      // Busca detalhes do item se existirem
      final details = barcodeManager.getDetails(item.code);
      
      final body = json.encode({
        'codigo': item.code,
        'descricao': details?.descricao ?? 'Patrimônio ${item.code}',
        'localizacao': details?.localizacao,
        'oldcode': details?.oldCode,
        'valor': details?.valorAquisicao,
        'status': item.status.index,
      });
      
      final response = await http.put(
        Uri.parse('$baseUrl/tombamentos/$id'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 10));

      print('📥 Resposta - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Item ${item.code} atualizado com sucesso!');
      } else {
        print('❌ Erro ao atualizar item: ${response.statusCode}');
        print('📄 Body: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro ao atualizar item: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
    }
  }

  /// Remove um item da API
  Future<void> removeItem(String code) async {
    if (_isSyncing) return;
    
    try {
      print('🗑️  Removendo item: $code da API...');
      
      // Primeiro busca o item pelo código para obter o ID e verificar se tem foto
      final getResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$code'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (getResponse.statusCode != 200) {
        print('❌ Item $code não encontrado na API para remoção');
        return;
      }
      
      final data = json.decode(utf8.decode(getResponse.bodyBytes));
      final id = data['id'];
      final foto = data['foto'];
      
      // Se tem foto, tenta deletar primeiro
      if (foto != null && foto != '') {
        print('🖼️  Item tem foto, tentando deletar: $foto');
        try {
          // Tenta DELETE /tombamentos/:id/foto
          final fotoResponse = await http.delete(
            Uri.parse('$baseUrl/tombamentos/$id/foto'),
            headers: _headers,
          ).timeout(const Duration(seconds: 10));
          
          if (fotoResponse.statusCode == 200 || fotoResponse.statusCode == 204) {
            print('✅ Foto deletada com sucesso!');
          } else {
            print('⚠️  Não foi possível deletar a foto (${fotoResponse.statusCode}), continuando com remoção do tombamento...');
          }
        } catch (fotoError) {
          print('⚠️  Erro ao deletar foto: $fotoError');
          print('   Continuando com remoção do tombamento...');
        }
      }
      
      // Remove o tombamento pelo ID
      final response = await http.delete(
        Uri.parse('$baseUrl/tombamentos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Item $code removido com sucesso!');
        
        // Remove foto local também
        await barcodeManager.removePhotoForCode(code);
      } else {
        print('❌ Erro ao remover item: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao remover item: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
    }
  }

  /// Sincroniza múltiplos detalhes para a API
  /// Usa endpoint batch para inserir todos de uma vez
  Future<void> syncDetails(Map<String, AssetDetails> details) async {
    try {
      print('📤 Sincronizando ${details.length} detalhes para API (batch)...');
      
      // Prepara array de tombamentos
      final List<Map<String, dynamic>> tombamentos = [];
      
      for (final detail in details.values) {
        // Valida campos obrigatórios
        if (detail.code == null || detail.code!.isEmpty) {
          print('  ⚠️  Código vazio ou nulo, pulando...');
          continue;
        }
        
        // Monta objeto removendo campos null explicitamente
        final Map<String, dynamic> tombamento = {
          'codigo': detail.code,
          'descricao': detail.descricao?.isNotEmpty == true 
              ? detail.descricao 
              : 'Patrimônio ${detail.code}',
          'status': 1, // Status padrão: encontrado
        };
        
        // Adiciona campos opcionais apenas se não forem vazios
        if (detail.localizacao != null && detail.localizacao!.isNotEmpty) {
          tombamento['localizacao'] = detail.localizacao;
        }
        if (detail.oldCode != null && detail.oldCode!.isNotEmpty) {
          tombamento['oldcode'] = detail.oldCode;
        }
        if (detail.valorAquisicao != null && detail.valorAquisicao!.isNotEmpty) {
          // Converte vírgula para ponto (formato brasileiro -> inglês)
          tombamento['valor'] = detail.valorAquisicao!.replaceAll(',', '.');
        }
        
        tombamentos.add(tombamento);
      }
      
      if (tombamentos.isEmpty) {
        print('⚠️  Nenhum tombamento válido para sincronizar');
        return;
      }
      
      print('📦 Enviando ${tombamentos.length} tombamentos em lote...');
      
      // Envia para endpoint batch
      final body = json.encode({'tombamentos': tombamentos});
      
      final response = await http.post(
        Uri.parse('$baseUrl/tombamentos/batch'),
        headers: _headers,
        body: body,
      ).timeout(const Duration(seconds: 60)); // Timeout maior para batch

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final sucessos = data['sucessos'] ?? 0;
        final erros = data['erros'] ?? 0;
        
        print('✅ Sincronização batch concluída:');
        print('   Sucessos: $sucessos');
        print('   Erros: $erros');
        
        // Mostra detalhes dos erros se houver
        if (data['errosDetalhes'] != null && (data['errosDetalhes'] as List).isNotEmpty) {
          print('   Detalhes dos erros:');
          for (final erro in data['errosDetalhes']) {
            print('     ❌ ${erro['codigo']}: ${erro['error']}');
          }
        }
      } else {
        print('❌ Erro na sincronização batch: ${response.statusCode}');
        print('   Resposta: ${response.body}');
      }
    } catch (e) {
      print('❌ Erro ao sincronizar detalhes: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
    }
  }

  /// Verifica conectividade com a API
  Future<bool> checkConnection() async {
    try {
      print('🔍 Verificando conexão com API: $baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Conexão com API estabelecida!');
        return true;
      } else {
        print('⚠️  API respondeu com status: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ Não foi possível conectar com a API: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
      return false;
    }
  }

  /// Faz upload de uma foto para a API e associa ao tombamento
  /// Retorna a URL da foto se sucesso, null se falhar
  Future<String?> uploadPhoto(String code, String filePath) async {
    if (_isSyncing) return null;
    
    try {
      print('📤 Fazendo upload de foto para: $code');
      print('   Arquivo: $filePath');
      
      // Primeiro, busca o ID e dados do tombamento
      final getResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$code'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode != 200) {
        print('❌ Tombamento não encontrado: $code');
        return null;
      }

      final tombamento = json.decode(utf8.decode(getResponse.bodyBytes));
      final id = tombamento['id'];
      
      print('📝 ID encontrado: $id, enviando foto...');

      // Primeiro, tente o endpoint que você confirmou funcionar no Postman:
      // POST /tombamentos/:id/foto (form-data, campo 'foto')
      try {
        print('🔄 Tentando POST /tombamentos/$id/foto...');
        print('   URL completa: $baseUrl/tombamentos/$id/foto');
        final uri = Uri.parse('$baseUrl/tombamentos/$id/foto');
        final request = http.MultipartRequest('POST', uri);

        // Adiciona o arquivo da foto com contentType explícito
        print('   Lendo arquivo: $filePath');
        final file = await http.MultipartFile.fromPath(
          'foto', 
          filePath,
          contentType: http_parser.MediaType('image', 'jpeg'),
        );
        request.files.add(file);
        print('   Arquivo adicionado: ${file.filename}, tamanho: ${file.length} bytes, tipo: ${file.contentType}');

        print('   Enviando requisição...');
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final response = await http.Response.fromStream(streamedResponse);
        
        print('   Status da resposta: ${response.statusCode}');
        print('   Body da resposta: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final fotoUrl = data['foto'] as String?;
          print('   Foto retornada pela API: $fotoUrl');
          if (fotoUrl != null) {
            final fotoCompleta = fotoUrl.startsWith('http') ? fotoUrl : '$baseUrl$fotoUrl';
            print('✅ Upload concluído via POST /:id/foto! URL: $fotoCompleta');
            await barcodeManager.setPhotoForCode(code, fotoCompleta);
            return fotoCompleta;
          } else {
            print('❌ API não retornou URL da foto');
            throw Exception('Foto URL missing');
          }
        } else if (response.statusCode == 404) {
          print('⚠️  Endpoint POST /tombamentos/$id/foto não existe (404), tentando alternativas...');
          throw Exception('Not found');
        } else {
          print('❌ Erro no upload POST /:id/foto: ${response.statusCode}');
          print('   Resposta completa: ${response.body}');
          // continue to fallbacks
          throw Exception('Upload failed');
        }
      } catch (firstErr) {
        print('⚠️  Primeira tentativa (/tombamentos/$id/foto) falhou: $firstErr');

        // Em seguida, tente o endpoint genérico POST /tombamentos/upload
        try {
          print('🔄 Tentando POST /tombamentos/upload...');
          final uri = Uri.parse('$baseUrl/tombamentos/upload');
          final request = http.MultipartRequest('POST', uri);
          request.fields['codigo'] = code;
          request.fields['id'] = id.toString();
          final file = await http.MultipartFile.fromPath(
            'foto', 
            filePath,
            contentType: http_parser.MediaType('image', 'jpeg'),
          );
          request.files.add(file);

          final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
          final response = await http.Response.fromStream(streamedResponse);

          if (response.statusCode == 200 || response.statusCode == 201) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            final fotoUrl = data['foto'] as String?;
            if (fotoUrl != null) {
              final fotoCompleta = fotoUrl.startsWith('http') ? fotoUrl : '$baseUrl$fotoUrl';
              print('✅ Upload concluído via POST /tombamentos/upload! URL: $fotoCompleta');
              await barcodeManager.setPhotoForCode(code, fotoCompleta);
              return fotoCompleta;
            }
          } else if (response.statusCode == 404) {
            print('⚠️  Endpoint /tombamentos/upload não existe, tentando PUT como último recurso...');
            throw Exception('Endpoint not found');
          } else {
            print('❌ Erro no upload POST /upload: ${response.statusCode}');
            print('   Resposta: ${response.body}');
            throw Exception('Upload failed');
          }
        } catch (uploadError) {
          print('⚠️  Tentativa POST /upload falhou: $uploadError');

          // Por fim, tente enviar multipart no PUT /tombamentos/:id (atualiza o registro)
          try {
            print('🔄 Tentando PUT /tombamentos/$id com multipart...');
            final uri = Uri.parse('$baseUrl/tombamentos/$id');
            final request = http.MultipartRequest('PUT', uri);

            request.fields['codigo'] = code;
            request.fields['descricao'] = tombamento['descricao']?.toString() ?? 'Patrimônio $code';
            if (tombamento['localizacao'] != null) request.fields['localizacao'] = tombamento['localizacao'].toString();
            if (tombamento['oldcode'] != null) request.fields['oldcode'] = tombamento['oldcode'].toString();
            if (tombamento['valor'] != null) request.fields['valor'] = tombamento['valor'].toString();
            if (tombamento['status'] != null) request.fields['status'] = tombamento['status'].toString();

            final file = await http.MultipartFile.fromPath(
              'foto', 
              filePath,
              contentType: http_parser.MediaType('image', 'jpeg'),
            );
            request.files.add(file);

            final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
            final response = await http.Response.fromStream(streamedResponse);

            if (response.statusCode == 200 || response.statusCode == 201) {
              final data = json.decode(utf8.decode(response.bodyBytes));
              final fotoUrl = data['foto'] as String?;
              if (fotoUrl != null) {
                final fotoCompleta = fotoUrl.startsWith('http') ? fotoUrl : '$baseUrl$fotoUrl';
                print('✅ Upload concluído via PUT! URL: $fotoCompleta');
                await barcodeManager.setPhotoForCode(code, fotoCompleta);
                return fotoCompleta;
              }
            } else {
              print('❌ Erro no upload PUT: ${response.statusCode}');
              print('   Resposta: ${response.body}');
            }
          } catch (putErr) {
            print('❌ Todas as tentativas de upload falharam: $putErr');
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Erro ao fazer upload da foto: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
      return null;
    }
  }

  /// Remove apenas a foto de um tombamento (mantém o tombamento)
  Future<bool> removePhoto(String code) async {
    if (_isSyncing) return false;
    
    try {
      print('🗑️  Removendo foto do tombamento: $code');
      
      // Busca o ID do tombamento
      final getResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$code'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode != 200) {
        print('❌ Tombamento não encontrado: $code');
        return false;
      }

      final data = json.decode(utf8.decode(getResponse.bodyBytes));
      final id = data['id'];
      final foto = data['foto'];
      
      if (foto == null || foto == '') {
        print('⚠️  Tombamento não possui foto');
        return false;
      }
      
      print('📝 ID encontrado: $id, removendo foto da API...');
      
      // Remove foto via API
      final response = await http.delete(
        Uri.parse('$baseUrl/tombamentos/$id/foto'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Foto removida da API com sucesso!');
        
        // Remove foto local também
        await barcodeManager.removePhotoForCode(code);
        
        return true;
      } else {
        print('❌ Erro ao remover foto: ${response.statusCode}');
        print('   Resposta: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao remover foto: $e');
      print('⚠️  Verifique se está conectado no WiFi da empresa');
      return false;
    }
  }

  /// Limpa todos os dados do servidor (usar com cuidado!)
  Future<void> clearAll() async {
    try {
      print('🗑️  Limpando todos os dados da API...');
      
      // Primeiro tenta o endpoint batch (se existir)
      try {
        final response = await http.delete(
          Uri.parse('$baseUrl/tombamentos/all'),
          headers: _headers,
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200 || response.statusCode == 204) {
          print('✅ Dados limpos com sucesso via /tombamentos/all!');
          return;
        } else if (response.statusCode != 404) {
          print('❌ Erro ao limpar dados: ${response.statusCode}');
          return;
        }
        // Se 404, continua para deletar individualmente
        print('⚠️  Endpoint /tombamentos/all não existe, deletando individualmente...');
      } catch (e) {
        print('⚠️  Erro no endpoint batch: $e');
        print('   Tentando deletar individualmente...');
      }
      
      // Se o endpoint batch não existe, busca todos e deleta um por um
      print('📋 Buscando todos os tombamentos...');
      final getResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (getResponse.statusCode != 200) {
        print('❌ Erro ao buscar tombamentos: ${getResponse.statusCode}');
        return;
      }

      final List<dynamic> tombamentos = json.decode(utf8.decode(getResponse.bodyBytes));
      print('🗑️  Deletando ${tombamentos.length} tombamentos...');
      
      int success = 0;
      int errors = 0;
      
      for (final tombamento in tombamentos) {
        try {
          final id = tombamento['id'];
          final codigo = tombamento['codigo'];
          
          final response = await http.delete(
            Uri.parse('$baseUrl/tombamentos/$id'),
            headers: _headers,
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 || response.statusCode == 204) {
            success++;
            print('  ✅ $codigo deletado');
          } else {
            errors++;
            print('  ❌ Erro ao deletar $codigo: ${response.statusCode}');
          }
        } catch (e) {
          errors++;
          print('  ❌ Erro ao deletar: $e');
        }
        
        // Pequeno delay para não sobrecarregar
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      print('✅ Limpeza concluída: $success deletados, $errors erros');
    } catch (e) {
      print('❌ Erro ao limpar dados: $e');
    }
  }
}
