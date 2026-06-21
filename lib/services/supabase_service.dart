import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/care_tip.dart';
import '../models/log_entry.dart';
import '../models/medication.dart';
import '../models/milestone.dart';
import '../models/pet.dart';
import '../models/pet_member.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/weight_record.dart';

class SupabaseService {
  Future<Pet> ensurePet() async {
    final existing = await Supabase.instance.client
        .from('pets')
        .select()
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      return Pet.fromMap(existing);
    }

    await Supabase.instance.client.from('pets').insert({
      'name': '몽이',
      'species': '강아지',
      'adoption_date': '2024-02-14',
    });

    final row = await Supabase.instance.client
        .from('pets')
        .select()
        .limit(1)
        .single();

    return Pet.fromMap(row);
  }

  Future<List<Pet>> fetchPets() async {
    final rows = await Supabase.instance.client
        .from('pets')
        .select()
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => Pet.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Pet> createPet({
    required String name,
    required String species,
    String? breed,
    required DateTime adoptionDate,
    DateTime? birthday,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'species': species,
      'adoption_date': _formatDate(adoptionDate),
    };
    if (birthday != null) {
      payload['birthday'] = _formatDate(birthday);
    }
    if (breed != null && breed.isNotEmpty) {
      payload['breed'] = breed;
    }

    await Supabase.instance.client.from('pets').insert(payload);

    final row = await Supabase.instance.client
        .from('pets')
        .select()
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    return Pet.fromMap(row);
  }

  Future<Pet> updatePet({
    required String id,
    required String name,
    required String species,
    String? breed,
    required DateTime adoptionDate,
    DateTime? birthday,
  }) async {
    final updated = await Supabase.instance.client
        .from('pets')
        .update({
          'name': name,
          'species': species,
          'breed': (breed == null || breed.isEmpty) ? null : breed,
          'adoption_date': _formatDate(adoptionDate),
          'birthday': birthday == null ? null : _formatDate(birthday),
        })
        .eq('id', id)
        .select()
        .single();

    return Pet.fromMap(updated);
  }

  Future<List<LogEntry>> fetchLogs(String petId) async {
    final rows = await Supabase.instance.client
        .from('logs')
        .select()
        .eq('pet_id', petId)
        .order('logged_at', ascending: false);

    return (rows as List)
        .map((row) => LogEntry.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<LogEntry> addLog(
    String petId,
    String content, {
    String? photoUrl,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final inserted = await Supabase.instance.client
        .from('logs')
        .insert({
          'pet_id': petId,
          'author_id': userId,
          'content': content,
          'photo_url': photoUrl,
        })
        .select()
        .single();

    return LogEntry.fromMap(inserted);
  }

  Future<LogEntry> updateLog(
    String id,
    String content, {
    String? photoUrl,
  }) async {
    final updated = await Supabase.instance.client
        .from('logs')
        .update({
          'content': content,
          'photo_url': photoUrl,
        })
        .eq('id', id)
        .select()
        .single();

    return LogEntry.fromMap(updated);
  }

  Future<void> deleteLog(String id) async {
    await Supabase.instance.client.from('logs').delete().eq('id', id);
  }

  Future<String> uploadLogPhoto(
    Uint8List bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from('pet-photos')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return Supabase.instance.client.storage
        .from('pet-photos')
        .getPublicUrl(path);
  }

  Future<List<WeightRecord>> fetchWeights(String petId) async {
    final rows = await Supabase.instance.client
        .from('weight_records')
        .select()
        .eq('pet_id', petId)
        .order('measured_at', ascending: true);

    return (rows as List)
        .map((row) => WeightRecord.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<WeightRecord> addWeight(
    String petId,
    double weightKg,
    DateTime measuredAt,
  ) async {
    final y = measuredAt.year.toString().padLeft(4, '0');
    final m = measuredAt.month.toString().padLeft(2, '0');
    final d = measuredAt.day.toString().padLeft(2, '0');
    final measuredAtStr = '$y-$m-$d';

    final inserted = await Supabase.instance.client
        .from('weight_records')
        .insert({
          'pet_id': petId,
          'weight_kg': weightKg,
          'measured_at': measuredAtStr,
        })
        .select()
        .single();

    return WeightRecord.fromMap(inserted);
  }

  Future<void> deleteWeight(String id) async {
    await Supabase.instance.client
        .from('weight_records')
        .delete()
        .eq('id', id);
  }

  Future<List<Vaccination>> fetchVaccinations(String petId) async {
    final rows = await Supabase.instance.client
        .from('vaccinations')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Vaccination.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Vaccination> addVaccination(
    String petId, {
    required String name,
    required DateTime date,
    String? memo,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final isFuture = dateOnly.isAfter(today);

    final payload = <String, dynamic>{
      'pet_id': petId,
      'name': name,
      if (isFuture) 'next_due_at': _formatDate(date),
      if (!isFuture) 'administered_at': _formatDate(date),
    };
    if (memo != null && memo.isNotEmpty) {
      payload['memo'] = memo;
    }

    final inserted = await Supabase.instance.client
        .from('vaccinations')
        .insert(payload)
        .select()
        .single();

    return Vaccination.fromMap(inserted);
  }

  Future<void> updateVaccination(
    String id, {
    String? name,
    DateTime? administeredAt,
    DateTime? nextDueAt,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'name': ?name,
      'administered_at':
          administeredAt == null ? null : _formatDate(administeredAt),
      'next_due_at': nextDueAt == null ? null : _formatDate(nextDueAt),
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    await Supabase.instance.client
        .from('vaccinations')
        .update(payload)
        .eq('id', id);
  }

  Future<void> deleteVaccination(String id) async {
    await Supabase.instance.client.from('vaccinations').delete().eq('id', id);
  }

  Future<void> completeVaccination(
    String id, {
    DateTime? nextDue,
  }) async {
    final row = await Supabase.instance.client
        .from('vaccinations')
        .select('pet_id, name, memo, next_due_at')
        .eq('id', id)
        .single();

    final dueRaw = row['next_due_at'] as String?;
    if (dueRaw == null) {
      throw StateError('완료할 예정 기록이 없습니다.');
    }
    final dueDate = DateTime.parse(dueRaw);

    await Supabase.instance.client
        .from('vaccinations')
        .update({
          'administered_at': _formatDate(dueDate),
          'next_due_at': null,
        })
        .eq('id', id);

    if (nextDue != null) {
      final petId = row['pet_id'] as String;
      final name = row['name'] as String;
      final memo = row['memo'] as String?;
      final newPayload = <String, dynamic>{
        'pet_id': petId,
        'name': name,
        'next_due_at': _formatDate(nextDue),
      };
      if (memo != null) {
        newPayload['memo'] = memo;
      }
      await Supabase.instance.client.from('vaccinations').insert(newPayload);
    }
  }

  Future<List<Milestone>> fetchMilestones(String petId) async {
    final rows = await Supabase.instance.client
        .from('milestones')
        .select()
        .eq('pet_id', petId)
        .order('achieved_at', ascending: false);

    return (rows as List)
        .map((row) => Milestone.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Milestone> addMilestone(
    String petId, {
    required String title,
    required DateTime achievedAt,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'title': title,
      'achieved_at': _formatDate(achievedAt),
    };
    if (memo != null && memo.isNotEmpty) {
      payload['memo'] = memo;
    }

    final inserted = await Supabase.instance.client
        .from('milestones')
        .insert(payload)
        .select()
        .single();

    return Milestone.fromMap(inserted);
  }

  Future<void> deleteMilestone(String id) async {
    await Supabase.instance.client.from('milestones').delete().eq('id', id);
  }

  Future<List<Medication>> fetchMedications(String petId) async {
    final rows = await Supabase.instance.client
        .from('medications')
        .select()
        .eq('pet_id', petId)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((row) => Medication.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Medication> addMedication(
    String petId, {
    required String name,
    required MedicationKind kind,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? memo,
    bool reminderEnabled = false,
    List<String> times = const [],
    List<int> weekdays = const [],
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'name': name,
      'kind': kind.apiValue,
      'reminder_enabled': reminderEnabled,
      'times': times,
      'weekdays': weekdays,
    };
    if (dosage != null && dosage.isNotEmpty) payload['dosage'] = dosage;
    if (frequency != null && frequency.isNotEmpty) {
      payload['frequency'] = frequency;
    }
    if (startDate != null) payload['start_date'] = _formatDate(startDate);
    if (endDate != null) payload['end_date'] = _formatDate(endDate);
    if (memo != null && memo.isNotEmpty) payload['memo'] = memo;

    final inserted = await Supabase.instance.client
        .from('medications')
        .insert(payload)
        .select()
        .single();

    return Medication.fromMap(inserted);
  }

  Future<Medication> updateMedication(
    String id, {
    required String name,
    required MedicationKind kind,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? memo,
    bool reminderEnabled = false,
    List<String> times = const [],
    List<int> weekdays = const [],
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'kind': kind.apiValue,
      'dosage': (dosage == null || dosage.isEmpty) ? null : dosage,
      'frequency':
          (frequency == null || frequency.isEmpty) ? null : frequency,
      'start_date': startDate == null ? null : _formatDate(startDate),
      'end_date': endDate == null ? null : _formatDate(endDate),
      'memo': (memo == null || memo.isEmpty) ? null : memo,
      'reminder_enabled': reminderEnabled,
      'times': times,
      'weekdays': weekdays,
    };

    final updated = await Supabase.instance.client
        .from('medications')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    return Medication.fromMap(updated);
  }

  Future<void> deleteMedication(String id) async {
    await Supabase.instance.client.from('medications').delete().eq('id', id);
  }

  Future<List<VetVisit>> fetchVetVisits(String petId) async {
    final rows = await Supabase.instance.client
        .from('vet_visits')
        .select()
        .eq('pet_id', petId)
        .order('visited_at', ascending: false);

    return (rows as List)
        .map((row) => VetVisit.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<VetVisit> addVetVisit(
    String petId, {
    required DateTime visitedAt,
    String? hospital,
    String? reason,
    String? diagnosis,
    String? treatment,
    int? cost,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'visited_at': _formatDate(visitedAt),
    };
    if (hospital != null && hospital.isNotEmpty) payload['hospital'] = hospital;
    if (reason != null && reason.isNotEmpty) payload['reason'] = reason;
    if (diagnosis != null && diagnosis.isNotEmpty) {
      payload['diagnosis'] = diagnosis;
    }
    if (treatment != null && treatment.isNotEmpty) {
      payload['treatment'] = treatment;
    }
    if (cost != null) payload['cost'] = cost;
    if (memo != null && memo.isNotEmpty) payload['memo'] = memo;

    final inserted = await Supabase.instance.client
        .from('vet_visits')
        .insert(payload)
        .select()
        .single();

    return VetVisit.fromMap(inserted);
  }

  Future<VetVisit> updateVetVisit(
    String id, {
    required DateTime visitedAt,
    String? hospital,
    String? reason,
    String? diagnosis,
    String? treatment,
    int? cost,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'visited_at': _formatDate(visitedAt),
      'hospital': (hospital == null || hospital.isEmpty) ? null : hospital,
      'reason': (reason == null || reason.isEmpty) ? null : reason,
      'diagnosis': (diagnosis == null || diagnosis.isEmpty) ? null : diagnosis,
      'treatment': (treatment == null || treatment.isEmpty) ? null : treatment,
      'cost': cost,
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    final updated = await Supabase.instance.client
        .from('vet_visits')
        .update(payload)
        .eq('id', id)
        .select()
        .single();

    return VetVisit.fromMap(updated);
  }

  Future<void> deleteVetVisit(String id) async {
    await Supabase.instance.client.from('vet_visits').delete().eq('id', id);
  }

  Future<List<PetMember>> fetchPetMembers(String petId) async {
    final result = await Supabase.instance.client.rpc(
      'get_pet_members',
      params: {'p_pet_id': petId},
    );
    final rows = (result as List?) ?? const [];
    return rows
        .map((row) => PetMember.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<String> createPetInvite(String petId) async {
    final result = await Supabase.instance.client.rpc(
      'create_pet_invite',
      params: {'p_pet_id': petId},
    );
    final code = result as String?;
    if (code == null || code.isEmpty) {
      throw StateError('초대 코드를 만들지 못했어요.');
    }
    return code;
  }

  Future<({String petId, String? petName})> redeemPetInvite(
    String code,
  ) async {
    final result = await Supabase.instance.client.rpc(
      'redeem_pet_invite',
      params: {'p_code': code},
    );
    final rows = (result as List?) ?? const [];
    if (rows.isEmpty) {
      throw StateError('초대 코드를 인식할 수 없는 형식이에요.');
    }
    final row = rows.first as Map<String, dynamic>;
    final petId = row['pet_id'] as String?;
    if (petId == null) {
      throw StateError('초대 코드를 인식할 수 없는 형식이에요.');
    }
    return (petId: petId, petName: row['pet_name'] as String?);
  }

  Future<void> removePetMember(String petId, String userId) async {
    await Supabase.instance.client.rpc(
      'remove_pet_member',
      params: {'p_pet_id': petId, 'p_user_id': userId},
    );
  }

  Future<void> leavePet(String petId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인 정보가 없어요.');
    }
    await Supabase.instance.client.from('pet_members').delete().match({
      'pet_id': petId,
      'user_id': userId,
    });
  }

  Future<List<CareTip>> fetchRelevantCareTips({
    required String species,
    required String lifeStage,
    String? breed,
  }) async {
    final stageFilter = 'life_stage.eq.$lifeStage,life_stage.is.null';
    final breedFilter = (breed == null || breed.isEmpty)
        ? 'breed.is.null'
        : 'breed.is.null,breed.eq.$breed';
    final rows = await Supabase.instance.client
        .from('care_tips')
        .select()
        .eq('species', species)
        .or(stageFilter)
        .or(breedFilter)
        .order('breed', ascending: false)
        .order('life_stage', ascending: true)
        .order('title', ascending: true);

    return (rows as List)
        .map((row) => CareTip.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<CareTip>> fetchAllCareTips() async {
    final rows = await Supabase.instance.client
        .from('care_tips')
        .select()
        .order('species', ascending: true)
        .order('life_stage', ascending: true)
        .order('title', ascending: true);

    return (rows as List)
        .map((row) => CareTip.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitFeedback({
    required String category,
    required String message,
    String? contact,
    required String appVersion,
  }) async {
    final payload = <String, dynamic>{
      'category': category,
      'message': message,
      'app_version': appVersion,
    };
    if (contact != null && contact.isNotEmpty) {
      payload['contact'] = contact;
    }
    await Supabase.instance.client.from('feedback').insert(payload);
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
