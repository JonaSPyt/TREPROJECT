/// Model que representa um Departamento.
/// Similar às "salas" do Google Classroom - agrupa tombamentos.
class Departamento {
  final int? id;
  final String codigo;
  final String nome;
  final String? descricao;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int totalTombamentos;

  Departamento({
    this.id,
    required this.codigo,
    required this.nome,
    this.descricao,
    this.createdAt,
    this.updatedAt,
    this.totalTombamentos = 0,
  });

  /// Cria um Departamento a partir de um JSON da API
  factory Departamento.fromJson(Map<String, dynamic> json) {
    return Departamento(
      id: json['id'],
      codigo: json['codigo'] ?? '',
      nome: json['nome'] ?? '',
      descricao: json['descricao'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at']) 
          : null,
      totalTombamentos: int.tryParse(json['total_tombamentos']?.toString() ?? '0') ?? 0,
    );
  }

  /// Converte o Departamento para JSON para enviar à API
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'codigo': codigo,
      'nome': nome,
      if (descricao != null && descricao!.isNotEmpty) 'descricao': descricao,
    };
  }

  /// Cria uma cópia do departamento com campos alterados
  Departamento copyWith({
    int? id,
    String? codigo,
    String? nome,
    String? descricao,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? totalTombamentos,
  }) {
    return Departamento(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalTombamentos: totalTombamentos ?? this.totalTombamentos,
    );
  }

  @override
  String toString() {
    return 'Departamento(id: $id, codigo: $codigo, nome: $nome, total: $totalTombamentos)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Departamento && other.id == id && other.codigo == codigo;
  }

  @override
  int get hashCode => id.hashCode ^ codigo.hashCode;
}
