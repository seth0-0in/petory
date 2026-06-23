import 'package:shared_preferences/shared_preferences.dart';

// Supabase의 pets 테이블과 매핑되는 모델 클래스.
class Pet {
  final String id;
  final String name;
  final String species;
  final String? breed;
  final DateTime adoptionDate;
  final DateTime? birthday;
  final String? photoUrl;
  final String? profileImageUrl;
  final bool isNeutered;
  final bool isRainbowBridge;

  const Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    required this.adoptionDate,
    this.birthday,
    this.photoUrl,
    this.profileImageUrl,
    this.isNeutered = false,
    this.isRainbowBridge = false,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    final birthdayRaw = map['birthday'] as String?;
    final breedRaw = map['breed'] as String?;
    final profileRaw = map['profile_image_url'] as String?;
    return Pet(
      id: map['id'] as String,
      name: map['name'] as String,
      species: map['species'] as String,
      breed: (breedRaw == null || breedRaw.isEmpty) ? null : breedRaw,
      adoptionDate: DateTime.parse(map['adoption_date'] as String),
      birthday: birthdayRaw == null ? null : DateTime.parse(birthdayRaw),
      photoUrl: map['photo_url'] as String?,
      profileImageUrl: (profileRaw == null || profileRaw.isEmpty)
          ? null
          : profileRaw,
      isNeutered: (map['is_neutered'] as bool?) ?? false,
      isRainbowBridge: (map['is_rainbow_bridge'] as bool?) ?? false,
    );
  }

  Pet copyWith({String? profileImageUrl}) {
    return Pet(
      id: id,
      name: name,
      species: species,
      breed: breed,
      adoptionDate: adoptionDate,
      birthday: birthday,
      photoUrl: photoUrl,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isNeutered: isNeutered,
      isRainbowBridge: isRainbowBridge,
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

  // 입양 후 경과한 해(완전한 해 수). 펫 나이의 보수적 하한치 (입양 시 0세였다고 가정).
  int get yearsSinceAdoption {
    final now = DateTime.now();
    var years = now.year - adoptionDate.year;
    if (now.month < adoptionDate.month ||
        (now.month == adoptionDate.month && now.day < adoptionDate.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  // 생일이 있을 때만 나이 계산. 생일 미입력 펫은 null.
  int? get ageYears {
    final bd = birthday;
    if (bd == null) return null;
    final now = DateTime.now();
    var years = now.year - bd.year;
    if (now.month < bd.month ||
        (now.month == bd.month && now.day < bd.day)) {
      years--;
    }
    return years < 0 ? 0 : years;
  }

  // 종에 따른 시니어 판정 기준 나이.
  // 강아지 8세, 고양이 10세, 그 외 5세 이상.
  int get seniorThresholdYears {
    final s = species.trim();
    if (s == '강아지' || s.toLowerCase() == 'dog') return 8;
    if (s == '고양이' || s.toLowerCase() == 'cat') return 10;
    return 5;
  }

  // 생일 기반 시니어 여부. 생일이 없으면 false (수동 토글로 판정해야 함).
  bool get isSeniorByBirthday {
    final years = ageYears;
    if (years == null) return false;
    return years >= seniorThresholdYears;
  }
}

// 생일 미입력 펫의 시니어 모드 수동 ON 여부를 SharedPreferences에 저장.
class SeniorModeStore {
  static const String _prefix = 'senior_manual_';

  static Future<bool> isManualOn(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$petId') ?? false;
  }

  static Future<void> setManualOn(String petId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      await prefs.setBool('$_prefix$petId', true);
    } else {
      await prefs.remove('$_prefix$petId');
    }
  }
}

// 수동 토글 > 생일 > 입양일 순으로 시니어 여부를 판정.
// - 수동 토글이 ON이면 항상 senior.
// - 생일이 있으면 생일 기준 나이로 판정.
// - 생일이 없으면 입양 후 경과 연수(≥ 시니어 임계)로 보수적 추정.
bool isSeniorEffective(Pet pet, {required bool manualOn}) {
  if (manualOn) return true;
  if (pet.birthday != null) return pet.isSeniorByBirthday;
  return pet.yearsSinceAdoption >= pet.seniorThresholdYears;
}
