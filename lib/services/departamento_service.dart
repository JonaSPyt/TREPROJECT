import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/departamento.dart';

/// Serviço responsável pela comunicação com a API de Departamentos.
/// Gerencia todas as operações CRUD de departamentos e vinculação de tombamentos.
class DepartamentoService {
  final String baseUrl;

  DepartamentoService({String? apiUrl})
      : baseUrl = apiUrl ?? dotenv.env['API_BASE_URL'] ?? 'http://192.168.200.91:3000';

  /// Headers padrão para requisições JSON
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  /// Importa tombamentos em lote usando o endpoint batch
  Future<Map<String, dynamic>> importarTombamentosBatch(
    int departamentoId,
    List<Map<String, dynamic>> tombamentos,
  ) async {
    try {
      print('📦 Importando ${tombamentos.length} tombamentos em lote para departamento $departamentoId...');
      final response = await http.post(
        Uri.parse('$baseUrl/departamentos/$departamentoId/tombamentos/batch'),
        headers: _headers,
        body: json.encode({'tombamentos': tombamentos}),
      ).timeout(const Duration(seconds: 120));
      print('🔵 [Batch] Status: \\${response.statusCode}');
      print('🔵 [Batch] Response body: \\${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Batch concluído: criados=${data['criados']}, atualizados=${data['atualizados']}, ignorados=${data['ignorados']}');
        return data;
      } else {
        try {
          final error = json.decode(response.body);
          print('❌ [Batch] Erro detalhado: $error');
          throw Exception(error['error'] ?? 'Erro ao importar tombamentos em lote');
        } catch (e2) {
          print('❌ [Batch] Erro ao decodificar resposta: ${response.body}');
          throw Exception('Erro ao importar tombamentos em lote: ${response.body}');
        }
      }
    } catch (e) {
      print('❌ Erro ao importar tombamentos em lote: $e');
      rethrow;
    }
  }

  /// Atualiza dados de um tombamento (descrição, localização, etc.)
  Future<Map<String, dynamic>> atualizarTombamento(
    int tombamentoId,
    Map<String, dynamic> dados,
  ) async {
    try {
      print('📝 Atualizando tombamento $tombamentoId...');
      final response = await http.put(
        Uri.parse('$baseUrl/tombamentos/$tombamentoId'),
        headers: _headers,
        body: json.encode(dados),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Tombamento atualizado');
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar tombamento');
      }
    } catch (e) {
      print('❌ Erro ao atualizar tombamento: $e');
      rethrow;
    }
  }

  /// Exclui um tombamento de um departamento
  Future<void> excluirTombamento(int departamentoId, int tombamentoId) async {
    try {
      print('🗑️ Excluindo tombamento $tombamentoId do departamento $departamentoId...');
      final response = await http.delete(
        Uri.parse('$baseUrl/departamentos/$departamentoId/tombamentos/$tombamentoId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Tombamento excluído');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao excluir tombamento');
      }
    } catch (e) {
      print('❌ Erro ao excluir tombamento: $e');
      rethrow;
    }
  }

  /// Exclui TODOS os tombamentos de um departamento (endpoint batch)
  Future<Map<String, dynamic>> excluirTodosTombamentos(int departamentoId) async {
    try {
      print('🗑️ Excluindo TODOS os tombamentos do departamento $departamentoId...');
      final response = await http.delete(
        Uri.parse('$baseUrl/departamentos/$departamentoId/tombamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ ${data['excluidos']} tombamentos excluídos do departamento ${data['departamento_nome']}');
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao excluir tombamentos');
      }
    } catch (e) {
      print('❌ Erro ao excluir tombamentos: $e');
      rethrow;
    }
  }

  /// Faz upload de foto para um tombamento
  Future<String> uploadFotoTombamento(int tombamentoId, dynamic fotoFile) async {
    try {
      print('📷 Enviando foto do tombamento $tombamentoId...');
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/tombamentos/$tombamentoId/foto'),
      );

      String filePath;
      if (fotoFile is String) {
        filePath = fotoFile;
      } else {
        filePath = fotoFile.path;
      }

      // Determina o tipo MIME baseado na extensão do arquivo
      final extension = filePath.toLowerCase().split('.').last;
      String mimeType;
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        case 'webp':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg'; // Default para jpg
      }

      request.files.add(await http.MultipartFile.fromPath(
        'foto',
        filePath,
        contentType: MediaType.parse(mimeType),
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Foto enviada: ${data['foto']}');
        return data['foto'] ?? '';
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao enviar foto');
      }
    } catch (e) {
      print('❌ Erro ao enviar foto: $e');
      rethrow;
    }
  }

  // ==================== CRUD DEPARTAMENTOS ====================

  /// Lista todos os departamentos
  Future<List<Departamento>> listarDepartamentos() async {
    try {
      print('📂 Carregando departamentos...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final departamentos = data.map((json) => Departamento.fromJson(json)).toList();
        print('✅ ${departamentos.length} departamentos carregados');
        return departamentos;
      } else {
        print('❌ Erro ao carregar departamentos: ${response.statusCode}');
        throw Exception('Erro ao carregar departamentos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao carregar departamentos: $e');
      rethrow;
    }
  }

  /// Busca um departamento por ID
  Future<Departamento> buscarDepartamento(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Departamento.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw Exception('Departamento não encontrado');
      } else {
        throw Exception('Erro ao buscar departamento: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao buscar departamento: $e');
      rethrow;
    }
  }

  /// Busca um departamento por código
  Future<Departamento> buscarPorCodigo(String codigo) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos/codigo/$codigo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return Departamento.fromJson(json.decode(utf8.decode(response.bodyBytes)));
      } else if (response.statusCode == 404) {
        throw Exception('Departamento não encontrado');
      } else {
        throw Exception('Erro ao buscar departamento: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao buscar departamento: $e');
      rethrow;
    }
  }

  /// Cria um novo departamento
  Future<Departamento> criarDepartamento(Departamento departamento) async {
    try {
      print('📂 Criando departamento: ${departamento.codigo}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/departamentos'),
        headers: _headers,
        body: json.encode(departamento.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        final created = Departamento.fromJson(json.decode(utf8.decode(response.bodyBytes)));
        print('✅ Departamento criado: ${created.codigo}');
        return created;
      } else if (response.statusCode == 409) {
        throw Exception('Código de departamento já existe');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao criar departamento');
      }
    } catch (e) {
      print('❌ Erro ao criar departamento: $e');
      rethrow;
    }
  }

  /// Atualiza um departamento existente
  Future<Departamento> atualizarDepartamento(int id, Departamento departamento) async {
    try {
      print('📂 Atualizando departamento: $id');
      
      final response = await http.put(
        Uri.parse('$baseUrl/departamentos/$id'),
        headers: _headers,
        body: json.encode(departamento.toJson()),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final updated = Departamento.fromJson(json.decode(utf8.decode(response.bodyBytes)));
        print('✅ Departamento atualizado: ${updated.codigo}');
        return updated;
      } else if (response.statusCode == 404) {
        throw Exception('Departamento não encontrado');
      } else {
        throw Exception('Erro ao atualizar departamento: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao atualizar departamento: $e');
      rethrow;
    }
  }

  /// Deleta um departamento (apenas se não tiver tombamentos vinculados)
  Future<void> deletarDepartamento(int id) async {
    try {
      print('🗑️ Deletando departamento: $id');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/departamentos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Departamento deletado');
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Não é possível deletar departamento com tombamentos');
      } else if (response.statusCode == 404) {
        throw Exception('Departamento não encontrado');
      } else {
        throw Exception('Erro ao deletar departamento: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao deletar departamento: $e');
      rethrow;
    }
  }

  // ==================== TOMBAMENTOS DO DEPARTAMENTO ====================

  /// Lista todos os tombamentos de um departamento
  Future<List<Map<String, dynamic>>> listarTombamentos(int departamentoId) async {
    try {
      print('📂 Carregando tombamentos do departamento $departamentoId...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos/$departamentoId/tombamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ ${data.length} tombamentos carregados');
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Erro ao carregar tombamentos: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro ao carregar tombamentos: $e');
      rethrow;
    }
  }

  /// Importa tombamentos para o departamento (NOVO FLUXO)
  /// Cria os tombamentos diretamente vinculados ao departamento.
  /// Se o código já existe, move/atualiza para este departamento.
  Future<Map<String, dynamic>> importarTombamentos(
    int departamentoId,
    List<Map<String, dynamic>> tombamentos,
  ) async {
    try {
      print('� Importando ${tombamentos.length} tombamentos para departamento $departamentoId...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/departamentos/$departamentoId/tombamentos'),
        headers: _headers,
        body: json.encode({'tombamentos': tombamentos}),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final criados = data['criados'] ?? 0;
        final atualizados = data['atualizados'] ?? 0;
        print('✅ Importação concluída: $criados criados, $atualizados atualizados');
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao importar tombamentos');
      }
    } catch (e) {
      print('❌ Erro ao importar tombamentos: $e');
      rethrow;
    }
  }

  /// Atualiza o status de um tombamento
  Future<Map<String, dynamic>> atualizarStatusTombamento(
    int tombamentoId,
    int status,
  ) async {
    try {
      print('� Atualizando status do tombamento $tombamentoId para $status...');
      
      final response = await http.put(
        Uri.parse('$baseUrl/tombamentos/$tombamentoId'),
        headers: _headers,
        body: json.encode({'status': status}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Status atualizado');
        return data;
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao atualizar status');
      }
    } catch (e) {
      print('❌ Erro ao atualizar status: $e');
      rethrow;
    }
  }

  /// Remove um tombamento do departamento (deleta)
  Future<void> removerTombamento(int tombamentoId) async {
    try {
      print('�️ Removendo tombamento $tombamentoId...');
      
      final response = await http.delete(
        Uri.parse('$baseUrl/tombamentos/$tombamentoId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('✅ Tombamento removido');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao remover tombamento');
      }
    } catch (e) {
      print('❌ Erro ao remover tombamento: $e');
      rethrow;
    }
  }

  /// Busca o departamento de um tombamento pelo código
  /// Retorna null se o código não estiver em nenhum departamento
  /// Suporta busca por sufixo: se o código escaneado for "87043854" e o 
  /// cadastrado for "43854", encontra o cadastrado
  Future<Departamento?> buscarDepartamentoPorTombamento(String codigo) async {
    try {
      print('🔍 Buscando departamento do tombamento $codigo...');
      
      // Primeiro tenta busca exata
      final response = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$codigo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['departamento'] != null) {
          return Departamento.fromJson(data['departamento']);
        }
        return null;
      } else if (response.statusCode == 404) {
        // Se não encontrou exato, tenta busca por sufixo
        return await _buscarPorSufixo(codigo);
      } else {
        return null;
      }
    } catch (e) {
      print('⚠️ Erro ao buscar departamento: $e');
      return null;
    }
  }

  /// Busca tombamento por sufixo - verifica se algum tombamento cadastrado
  /// é sufixo do código escaneado
  Future<Departamento?> _buscarPorSufixo(String codigoEscaneado) async {
    try {
      // Busca todos os tombamentos e verifica sufixo localmente
      final response = await http.get(
        Uri.parse('$baseUrl/tombamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> tombamentos = json.decode(utf8.decode(response.bodyBytes));
        
        // Procura tombamento cujo código é sufixo do escaneado
        for (final tomb in tombamentos) {
          final codigoCadastrado = tomb['codigo']?.toString() ?? '';
          if (codigoCadastrado.isNotEmpty && 
              codigoEscaneado.endsWith(codigoCadastrado) &&
              codigoCadastrado != codigoEscaneado) {
            print('🔍 [_buscarPorSufixo] Match: $codigoEscaneado → $codigoCadastrado');
            // Busca o departamento desse tombamento
            if (tomb['departamento'] != null) {
              return Departamento.fromJson(tomb['departamento']);
            } else if (tomb['departamento_id'] != null) {
              // Busca o departamento pelo ID
              return await buscarDepartamentoPorId(tomb['departamento_id']);
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Erro na busca por sufixo: $e');
      return null;
    }
  }

  /// Busca um tombamento por código (exato ou sufixo).
  /// Retorna um Map com 'codigo' (o código cadastrado encontrado), 
  /// 'departamento' (Departamento) e 'tombamento' (dados do tombamento).
  /// Retorna null se não encontrar.
  Future<Map<String, dynamic>?> buscarTombamentoPorCodigoOuSufixo(String codigoEscaneado) async {
    try {
      print('🔍 [buscarTombamentoPorCodigoOuSufixo] Buscando: $codigoEscaneado...');
      
      // Primeiro tenta busca exata
      final response = await http.get(
        Uri.parse('$baseUrl/tombamentos/codigo/$codigoEscaneado'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ Encontrado por código exato');
        return {
          'codigo': codigoEscaneado,
          'tombamento': data,
          'departamento': data['departamento'] != null 
              ? Departamento.fromJson(data['departamento']) 
              : null,
        };
      }
      
      // Se não encontrou exato, busca por sufixo
      final allResponse = await http.get(
        Uri.parse('$baseUrl/tombamentos'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (allResponse.statusCode == 200) {
        final List<dynamic> tombamentos = json.decode(utf8.decode(allResponse.bodyBytes));
        
        // Procura tombamento cujo código é sufixo do escaneado (prioriza match mais longo)
        Map<String, dynamic>? bestMatch;
        int bestLength = 0;
        
        for (final tomb in tombamentos) {
          final codigoCadastrado = tomb['codigo']?.toString() ?? '';
          if (codigoCadastrado.isNotEmpty && 
              codigoEscaneado.endsWith(codigoCadastrado) &&
              codigoCadastrado.length > bestLength) {
            bestLength = codigoCadastrado.length;
            bestMatch = tomb;
          }
        }
        
        if (bestMatch != null) {
          final codigoCadastrado = bestMatch['codigo']?.toString() ?? '';
          print('✅ [buscarTombamentoPorCodigoOuSufixo] Match por sufixo: $codigoEscaneado → $codigoCadastrado');
          
          Departamento? dept;
          if (bestMatch['departamento'] != null) {
            dept = Departamento.fromJson(bestMatch['departamento']);
          } else if (bestMatch['departamento_id'] != null) {
            dept = await buscarDepartamentoPorId(bestMatch['departamento_id']);
          }
          
          return {
            'codigo': codigoCadastrado,
            'tombamento': bestMatch,
            'departamento': dept,
          };
        }
      }
      
      print('❌ [buscarTombamentoPorCodigoOuSufixo] Tombamento não encontrado');
      return null;
    } catch (e) {
      print('⚠️ [buscarTombamentoPorCodigoOuSufixo] Erro ao buscar tombamento: $e');
      return null;
    }
  }

  /// Busca departamento por ID
  Future<Departamento?> buscarDepartamentoPorId(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/departamentos/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        return Departamento.fromJson(data);
      }
      return null;
    } catch (e) {
      print('⚠️ Erro ao buscar departamento por ID: $e');
      return null;
    }
  }

  /// Busca informações de múltiplos tombamentos (para evitar muitas chamadas)
  /// Retorna um Map<codigoTombamento, Departamento?>
  Future<Map<String, Departamento?>> buscarDepartamentosEmLote(List<String> codigos) async {
    if (codigos.isEmpty) return {};
    
    try {
      print('🔍 Buscando departamentos de ${codigos.length} tombamentos...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/tombamentos/buscar-departamentos'),
        headers: _headers,
        body: json.encode({'codigos': codigos}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final result = <String, Departamento?>{};
        
        // A resposta tem formato: { "total": X, "tombamentos": [...] }
        final tombamentos = data['tombamentos'] as List<dynamic>? ?? [];
        
        for (final item in tombamentos) {
          final codigo = item['codigo'] as String?;
          if (codigo != null) {
            if (item['departamento'] != null) {
              result[codigo] = Departamento.fromJson(item['departamento']);
            } else {
              result[codigo] = null;
            }
          }
        }
        
        print('✅ ${result.length} tombamentos processados');
        return result;
      } else {
        print('⚠️ Erro na API: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('⚠️ Erro ao buscar departamentos em lote: $e');
      return {};
    }
  }

  /// Lista tombamentos que não estão vinculados a nenhum departamento
  Future<List<Map<String, dynamic>>> listarTombamentosSemDepartamento() async {
    try {
      print('📋 Buscando tombamentos sem departamento...');
      final response = await http.get(
        Uri.parse('$baseUrl/tombamentos?sem_departamento=true'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        print('✅ ${data.length} tombamentos sem departamento encontrados');
        return data.cast<Map<String, dynamic>>();
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao listar tombamentos sem departamento');
      }
    } catch (e) {
      print('❌ Erro ao listar tombamentos sem departamento: $e');
      rethrow;
    }
  }

  /// Exclui um tombamento que não está vinculado a nenhum departamento
  Future<void> excluirTombamentoSemDepartamento(int tombamentoId) async {
    try {
      print('🗑️ Excluindo tombamento avulso $tombamentoId...');
      final response = await http.delete(
        Uri.parse('$baseUrl/tombamentos/$tombamentoId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('✅ Tombamento avulso excluído');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Erro ao excluir tombamento');
      }
    } catch (e) {
      print('❌ Erro ao excluir tombamento avulso: $e');
      rethrow;
    }
  }
}
