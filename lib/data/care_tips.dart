// 라이프스테이지 기준 (Pet.seniorThresholdYears와 동일):
// - 강아지: 0~1세 baby / 1~8세 adult / 8세+ senior
// - 고양이: 0~1세 baby / 1~10세 adult / 10세+ senior
// - 기타: 0~1세 baby / 1~5세 adult / 5세+ senior
String lifeStageFor({required String speciesKey, required DateTime? birthday}) {
  if (birthday == null) return 'adult';
  final now = DateTime.now();
  int years = now.year - birthday.year;
  final hadBirthdayThisYear =
      now.month > birthday.month ||
      (now.month == birthday.month && now.day >= birthday.day);
  if (!hadBirthdayThisYear) years -= 1;
  if (years < 1) return 'baby';
  final threshold = seniorThresholdYearsForKey(speciesKey);
  return years >= threshold ? 'senior' : 'adult';
}

int seniorThresholdYearsForKey(String speciesKey) {
  switch (speciesKey) {
    case 'dog':
      return 8;
    case 'cat':
      return 10;
    case 'other':
    default:
      return 5;
  }
}

String speciesKeyFromKorean(String species) {
  switch (species) {
    case '강아지':
      return 'dog';
    case '고양이':
      return 'cat';
    default:
      return 'other';
  }
}

String speciesLabel(String speciesKey) {
  switch (speciesKey) {
    case 'dog':
      return '강아지';
    case 'cat':
      return '고양이';
    case 'other':
    default:
      return '기타';
  }
}

String lifeStageLabel(String lifeStage) {
  switch (lifeStage) {
    case 'baby':
      return '유아기';
    case 'senior':
      return '노령기';
    case 'adult':
    default:
      return '성년기';
  }
}

const List<String> kSpeciesKeys = ['dog', 'cat', 'other'];
const List<String> kLifeStageKeys = ['baby', 'adult', 'senior'];
