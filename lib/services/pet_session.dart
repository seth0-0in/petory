import 'package:flutter/foundation.dart';

import '../models/pet.dart';

// 모든 하단 탭이 공유하는 펫 선택/리스트 상태.
//
// 사용:
//   ValueListenableBuilder<Pet?>(
//     valueListenable: PetSession.instance.selectedPet,
//     builder: (context, pet, _) { ... },
//   )
//
// 갱신:
//   PetSession.instance.setPets([...]);
//   PetSession.instance.setSelectedPet(pet);
//
// 데이터 변경 시(예: 펫 정보 수정 후) `bumpRev()`로 구독자에게 알림.
class PetSession {
  PetSession._();
  static final PetSession instance = PetSession._();

  final ValueNotifier<List<Pet>> pets = ValueNotifier<List<Pet>>(const []);
  final ValueNotifier<Pet?> selectedPet = ValueNotifier<Pet?>(null);
  // 펫 정보가 변경됐음을 알릴 때 사용하는 카운터.
  // 펫 자체 객체가 동일해도 내부 필드(예: 이름, 무지개다리 등)가 바뀐 경우에도
  // 화면을 갱신할 수 있도록 별도 리비전을 둠.
  final ValueNotifier<int> rev = ValueNotifier<int>(0);

  void setPets(List<Pet> next) {
    pets.value = List<Pet>.unmodifiable(next);
  }

  void setSelectedPet(Pet? next) {
    selectedPet.value = next;
  }

  void bumpRev() {
    rev.value = rev.value + 1;
  }

  void clear() {
    pets.value = const [];
    selectedPet.value = null;
    rev.value = rev.value + 1;
  }
}
