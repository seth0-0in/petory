// 모든 알림을 한 번에 재예약하는 헬퍼.
// SupabaseService에서 필요한 모든 데이터를 모아 NotificationService.rescheduleAll을 호출.
//
// 사용처:
//   - 할 일 추가/수정/삭제/완료 후
//   - 그 외 알림 영향이 있는 작업 후
//
// 실패는 모두 무시 (UX에 영향 없음).

import '../models/cage_schedule.dart';
import '../models/grooming_record.dart';
import '../models/heat_cycle.dart';
import '../models/medication.dart';
import '../models/pet.dart';
import '../models/todo_item.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

Future<void> rescheduleAllReminders(SupabaseService service) async {
  final notif = NotificationService.instance;
  if (!notif.isSupported || !notif.enabled) return;

  try {
    final pets = await service.fetchPets();
    final vacByPet = <String, List<Vaccination>>{};
    final medByPet = <String, List<Medication>>{};
    final vetByPet = <String, List<VetVisit>>{};
    final groomByPet = <String, List<GroomingRecord>>{};
    final heatByPet = <String, List<HeatCycle>>{};
    final cageByPet = <String, List<CageSchedule>>{};
    final seniorPetIds = <String>{};
    final healthLoggedTodayPetIds = <String>{};

    for (final p in pets) {
      vacByPet[p.id] = await service.fetchVaccinations(p.id);
      medByPet[p.id] = await service.fetchMedications(p.id);
      groomByPet[p.id] = await service.fetchGroomingRecords(p.id);
      if (!p.isNeutered && p.breed != '햄스터') {
        heatByPet[p.id] = await service.fetchHeatCycles(p.id);
      }
      if (p.species == '기타') {
        cageByPet[p.id] = await service.fetchCageSchedules(p.id);
      }
      final manualOn = await SeniorModeStore.isManualOn(p.id);
      if (isSeniorEffective(p, manualOn: manualOn)) {
        seniorPetIds.add(p.id);
        vetByPet[p.id] = await service.fetchVetVisits(p.id);
        final todayLog = await service.fetchTodayHealthLog(p.id);
        if (todayLog != null) healthLoggedTodayPetIds.add(p.id);
      }
    }

    final todos = await service.fetchAllTodos();

    await notif.rescheduleAll(
      pets: pets,
      vaccinationsByPetId: vacByPet,
      medicationsByPetId: medByPet,
      vetVisitsByPetId: vetByPet,
      groomingRecordsByPetId: groomByPet,
      heatCyclesByPetId: heatByPet,
      cageSchedulesByPetId: cageByPet,
      seniorPetIds: seniorPetIds,
      healthLoggedTodayPetIds: healthLoggedTodayPetIds,
      todos: todos.where((t) => !t.isDone).toList(),
    );
  } catch (_) {
    // 무시.
  }
}

// 오늘 미완료 할 일 개수 (모든 펫 통합).
Future<int> countTodayOpenTodos(SupabaseService service) async {
  try {
    final todos = await service.fetchAllTodos();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var count = 0;
    for (final t in todos) {
      if (t.isDone) continue;
      if (t.occursOn(today)) count++;
    }
    return count;
  } catch (_) {
    return 0;
  }
}
