// 대략적 기준: 강아지/고양이 라이프스테이지는 품종·크기에 따라 차이가 큽니다.
// - 강아지: <1세 baby / 1~7세 adult / 7세+ senior
// - 고양이: <1세 baby / 1~10세 adult / 10세+ senior
// - 기타: <1세 baby / 1~7세 adult / 7세+ senior (대략값)
String lifeStageFor({required String speciesKey, required DateTime? birthday}) {
  if (birthday == null) return 'adult';
  final now = DateTime.now();
  int years = now.year - birthday.year;
  final hadBirthdayThisYear =
      now.month > birthday.month ||
      (now.month == birthday.month && now.day >= birthday.day);
  if (!hadBirthdayThisYear) years -= 1;
  if (years < 1) return 'baby';
  switch (speciesKey) {
    case 'cat':
      return years >= 10 ? 'senior' : 'adult';
    case 'dog':
    case 'other':
    default:
      return years >= 7 ? 'senior' : 'adult';
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
