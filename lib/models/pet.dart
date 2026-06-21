// Supabase의 pets 테이블과 매핑되는 모델 클래스.
class Pet {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final DateTime adoptionDate;
  final DateTime? birthday;
  final String? photoUrl;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    required this.adoptionDate,
    this.birthday,
    this.photoUrl,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    final birthdayRaw = map['birthday'] as String?;
    final breedRaw = map['breed'] as String?;
    return Pet(
      id: map['id'] as String,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: (breedRaw == null || breedRaw.isEmpty) ? null : breedRaw,
      adoptionDate: DateTime.parse(map['adoption_date'] as String),
      birthday: birthdayRaw == null ? null : DateTime.parse(birthdayRaw),
      photoUrl: map['photo_url'] as String?,
    );
  }

  int get daysSinceAdoption {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final adopted = DateTime(
      adoptionDate.year,
      adoptionDate.month,
      adoptionDate.day,
    );
    return today.difference(adopted).inDays;
  }
}
