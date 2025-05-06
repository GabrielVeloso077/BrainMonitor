// lib/models/models.dart

enum PerfilTipo { admin, moderador, representante, usuarioComum }

extension PerfilTipoExtension on PerfilTipo {
  /// Retorna o ID numérico associado ao perfil
  int get id {
    switch (this) {
      case PerfilTipo.admin:
        return 1;
      case PerfilTipo.moderador:
        return 2;
      case PerfilTipo.representante:
        return 3;
      case PerfilTipo.usuarioComum:
        return 4;
    }
  }

  /// Converte um ID numérico em PerfilTipo
  static PerfilTipo fromId(int id) {
    switch (id) {
      case 1:
        return PerfilTipo.admin;
      case 2:
        return PerfilTipo.moderador;
      case 3:
        return PerfilTipo.representante;
      case 4:
        return PerfilTipo.usuarioComum;
      default:
        throw ArgumentError('PerfilTipo inválido: \$id');
    }
  }
}

class Cliente {
  final String id;
  final String nome;
  final String representanteId;
  final int maxUsuariosPorRepresentante;
  final List<String> dispositivos;

  Cliente({
    required this.id,
    required this.nome,
    required this.representanteId,
    required this.maxUsuariosPorRepresentante,
    required this.dispositivos,
  });

  /// Constrói Cliente a partir de um Map (por exemplo, snapshot.value)
  factory Cliente.fromMap(dynamic id, Map<String, dynamic> map) {
    final idStr = id.toString();
    final repVal = map['representanteId'];
    final repId = repVal != null ? repVal.toString() : '';
    final maxVal = map['maxUsuariosPorRepresentante'];
    final maxUsers =
        maxVal is int ? maxVal : int.tryParse(maxVal.toString()) ?? 0;
    return Cliente(
      id: idStr,
      nome: map['nome'] as String? ?? '',
      representanteId: repId,
      maxUsuariosPorRepresentante: maxUsers,
      dispositivos:
          (map['dispositivos'] as Map?)?.keys.cast<String>().toList() ?? [],
    );
  }

  /// Converte o Cliente em Map para escrita no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'representanteId': representanteId,
      'maxUsuariosPorRepresentante': maxUsuariosPorRepresentante,
      'dispositivos': {for (var d in dispositivos) d: true},
    };
  }
}

class Usuario {
  final String id;
  final String name;
  final String email;
  final PerfilTipo perfil;
  final String? clienteId;
  final List<String> dispositivosPermitidos;

  Usuario({
    required this.id,
    required this.name,
    required this.email,
    required this.perfil,
    this.clienteId,
    required this.dispositivosPermitidos,
  });

  /// Constrói Usuario a partir de um Map
  factory Usuario.fromMap(String id, Map<String, dynamic> map) {
    return Usuario(
      id: id,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      perfil: PerfilTipoExtension.fromId(map['perfilId'] as int),
      clienteId: map['clienteId']?.toString(),
      dispositivosPermitidos:
          (map['dispositivos'] as Map?)?.entries
              .where((e) => e.value == true)
              .map((e) => e.key as String)
              .toList() ??
          [],
    );
  }

  /// Converte o Usuario em Map para escrita no Firebase
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'perfilId': perfil.id,
      'dispositivos': {for (var d in dispositivosPermitidos) d: true},
    };
    if (clienteId != null) {
      map['clienteId'] = clienteId!;
    }
    return map;
  }
}
