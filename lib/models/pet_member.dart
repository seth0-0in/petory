enum PetMemberRole {
  owner,
  member;

  String get apiValue => name;

  String get label {
    switch (this) {
      case PetMemberRole.owner:
        return '소유자';
      case PetMemberRole.member:
        return '멤버';
    }
  }

  static PetMemberRole fromString(String? raw) {
    if (raw == 'owner') return PetMemberRole.owner;
    return PetMemberRole.member;
  }
}

class PetMember {
  final String userId;
  final String? email;
  final PetMemberRole role;

  const PetMember({
    required this.userId,
    required this.email,
    required this.role,
  });

  factory PetMember.fromMap(Map<String, dynamic> map) {
    final emailRaw = map['email'] as String?;
    return PetMember(
      userId: map['user_id'] as String,
      email: (emailRaw == null || emailRaw.isEmpty) ? null : emailRaw,
      role: PetMemberRole.fromString(map['role'] as String?),
    );
  }
}
