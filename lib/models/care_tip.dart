class CareTip {
  final String id;
  final String species;
  final String? lifeStage;
  final String? breed;
  final String title;
  final String body;

  const CareTip({
    required this.id,
    required this.species,
    this.lifeStage,
    this.breed,
    required this.title,
    required this.body,
  });

  factory CareTip.fromMap(Map<String, dynamic> map) {
    final breedRaw = map['breed'] as String?;
    final stageRaw = map['life_stage'] as String?;
    return CareTip(
      id: map['id'].toString(),
      species: map['species'] as String,
      lifeStage: (stageRaw == null || stageRaw.isEmpty) ? null : stageRaw,
      breed: (breedRaw == null || breedRaw.isEmpty) ? null : breedRaw,
      title: map['title'] as String,
      body: map['body'] as String,
    );
  }
}
