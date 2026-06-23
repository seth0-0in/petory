import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cage_log.dart';
import '../models/cage_schedule.dart';
import '../models/care_tip.dart';
import '../models/daily_health_log.dart';
import '../models/grooming_record.dart';
import '../models/heat_cycle.dart';
import '../models/log_comment.dart';
import '../models/log_entry.dart';
import '../models/log_like.dart';
import '../models/log_media.dart';
import '../models/medication.dart';
import '../models/milestone.dart';
import '../models/pet.dart';
import '../models/pet_member.dart';
import '../models/poop_log.dart';
import '../models/todo_item.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/water_log.dart';
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
    bool isNeutered = false,
    bool isRainbowBridge = false,
    String? profileImageUrl,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'species': species,
      'adoption_date': _formatDate(adoptionDate),
      'is_neutered': isNeutered,
      'is_rainbow_bridge': isRainbowBridge,
      'profile_image_url': profileImageUrl,
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
    bool isNeutered = false,
    bool isRainbowBridge = false,
    String? profileImageUrl,
  }) async {
    final updated = await Supabase.instance.client
        .from('pets')
        .update({
          'name': name,
          'species': species,
          'breed': (breed == null || breed.isEmpty) ? null : breed,
          'adoption_date': _formatDate(adoptionDate),
          'birthday': birthday == null ? null : _formatDate(birthday),
          'is_neutered': isNeutered,
          'is_rainbow_bridge': isRainbowBridge,
          'profile_image_url': profileImageUrl,
        })
        .eq('id', id)
        .select()
        .single();

    return Pet.fromMap(updated);
  }

  // Storage 'pet-photos' 버킷에 프로필 사진 업로드 후 public URL 반환.
  Future<String> uploadPetProfileImage(
    Uint8List bytes, {
    required String petId,
    String contentType = 'image/jpeg',
    String extension = 'jpg',
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final filename =
        '$userId/pets/$petId-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await Supabase.instance.client.storage
        .from('pet-photos')
        .uploadBinary(
          filename,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return Supabase.instance.client.storage
        .from('pet-photos')
        .getPublicUrl(filename);
  }

  // 펫의 프로필 사진만 단독 업데이트.
  Future<Pet> updatePetProfileImage(String petId, String? imageUrl) async {
    final updated = await Supabase.instance.client
        .from('pets')
        .update({'profile_image_url': imageUrl})
        .eq('id', petId)
        .select()
        .single();
    return Pet.fromMap(updated);
  }

  Future<List<LogEntry>> fetchLogs(String petId) async {
    final rows = await Supabase.instance.client
        .from('logs')
        .select('*, log_media(*), log_likes(*)')
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
        .select('*, log_media(*), log_likes(*)')
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

  // pet-videos 버킷이 있으면 거기에, 없으면 pet-photos 버킷에 업로드.
  Future<String> uploadLogVideo(
    Uint8List bytes, {
    String contentType = 'video/mp4',
    String extension = 'mp4',
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final filename =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    final storage = Supabase.instance.client.storage;

    try {
      await storage.from('pet-videos').uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return storage.from('pet-videos').getPublicUrl(filename);
    } on StorageException {
      // 버킷이 없거나 권한 문제면 pet-photos 버킷으로 폴백.
      await storage.from('pet-photos').uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return storage.from('pet-photos').getPublicUrl(filename);
    }
  }

  Future<List<LogMedia>> fetchMediaByLogId(String logId) async {
    final rows = await Supabase.instance.client
        .from('log_media')
        .select()
        .eq('log_id', logId)
        .order('position', ascending: true);

    return (rows as List)
        .map((row) => LogMedia.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<LogMedia> insertMedia({
    required String logId,
    required String mediaUrl,
    required String mediaType,
    required int position,
  }) async {
    final inserted = await Supabase.instance.client
        .from('log_media')
        .insert({
          'log_id': logId,
          'media_url': mediaUrl,
          'media_type': mediaType,
          'position': position,
        })
        .select()
        .single();

    return LogMedia.fromMap(inserted);
  }

  Future<void> deleteMedia(String id) async {
    await Supabase.instance.client.from('log_media').delete().eq('id', id);
  }

  Future<List<LogComment>> fetchComments(String logId) async {
    final rows = await Supabase.instance.client
        .from('log_comments')
        .select()
        .eq('log_id', logId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((row) => LogComment.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<LogComment> insertComment({
    required String logId,
    required String content,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인이 필요해요.');
    }
    // RLS 멤버십 트리거가 있는 테이블은 insert().select() 체이닝이 RETURNING
    // SELECT 단계에서 막힐 수 있어 분리 호출 패턴 사용.
    await Supabase.instance.client.from('log_comments').insert({
      'log_id': logId,
      'user_id': userId,
      'content': content,
    });
    final row = await Supabase.instance.client
        .from('log_comments')
        .select()
        .eq('log_id', logId)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .single();
    return LogComment.fromMap(row);
  }

  Future<void> deleteComment(String id) async {
    await Supabase.instance.client.from('log_comments').delete().eq('id', id);
  }

  Future<List<LogLike>> fetchLikes(String logId) async {
    final rows = await Supabase.instance.client
        .from('log_likes')
        .select()
        .eq('log_id', logId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((row) => LogLike.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // 좋아요 토글. 이미 누른 상태면 해제, 아니면 등록.
  // 반환값: 토글 후 좋아요 상태(true=좋아요 ON).
  Future<bool> toggleLike(String logId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('로그인이 필요해요.');
    }
    final existing = await Supabase.instance.client
        .from('log_likes')
        .select('id')
        .eq('log_id', logId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await Supabase.instance.client
          .from('log_likes')
          .delete()
          .eq('log_id', logId)
          .eq('user_id', userId);
      return false;
    }

    // unique(log_id, user_id) 제약으로 동시 요청은 23505로 막힘 → 그땐 결국
    // 좋아요 상태이므로 true 반환.
    try {
      await Supabase.instance.client.from('log_likes').insert({
        'log_id': logId,
        'user_id': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
    return true;
  }

  Future<List<TodoItem>> fetchTodos(String petId) async {
    final rows = await Supabase.instance.client
        .from('todo_items')
        .select()
        .eq('pet_id', petId)
        .order('due_date', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => TodoItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<TodoItem>> fetchAllTodos() async {
    final rows = await Supabase.instance.client
        .from('todo_items')
        .select()
        .order('due_date', ascending: true)
        .order('created_at', ascending: true);

    return (rows as List)
        .map((row) => TodoItem.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<TodoItem> insertTodo({
    required String petId,
    required String title,
    DateTime? dueDate,
    String? reminderTime,
    TodoRepeatType repeatType = TodoRepeatType.none,
    Set<int> repeatWeekdays = const {},
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'title': title,
      'due_date': dueDate == null ? null : _formatDate(dueDate),
      'reminder_time': reminderTime,
      'repeat_type': repeatTypeToApi(repeatType),
      'repeat_weekdays':
          repeatType == TodoRepeatType.weekly && repeatWeekdays.isNotEmpty
              ? repeatWeekdays.toList()
              : null,
      'note': (note == null || note.isEmpty) ? null : note,
      'is_done': false,
    };
    final inserted = await Supabase.instance.client
        .from('todo_items')
        .insert(payload)
        .select()
        .single();
    return TodoItem.fromMap(inserted);
  }

  Future<TodoItem> updateTodo({
    required String id,
    required String petId,
    required String title,
    DateTime? dueDate,
    String? reminderTime,
    TodoRepeatType repeatType = TodoRepeatType.none,
    Set<int> repeatWeekdays = const {},
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'title': title,
      'due_date': dueDate == null ? null : _formatDate(dueDate),
      'reminder_time': reminderTime,
      'repeat_type': repeatTypeToApi(repeatType),
      'repeat_weekdays':
          repeatType == TodoRepeatType.weekly && repeatWeekdays.isNotEmpty
              ? repeatWeekdays.toList()
              : null,
      'note': (note == null || note.isEmpty) ? null : note,
    };
    final updated = await Supabase.instance.client
        .from('todo_items')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return TodoItem.fromMap(updated);
  }

  Future<TodoItem> setTodoDone(String id, bool done) async {
    final payload = <String, dynamic>{
      'is_done': done,
      'done_at': done ? DateTime.now().toUtc().toIso8601String() : null,
    };
    final updated = await Supabase.instance.client
        .from('todo_items')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return TodoItem.fromMap(updated);
  }

  Future<void> deleteTodo(String id) async {
    await Supabase.instance.client.from('todo_items').delete().eq('id', id);
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

  Future<List<DailyHealthLog>> fetchRecentHealthLogs(
    String petId, {
    int days = 30,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(Duration(days: days - 1));
    final rows = await Supabase.instance.client
        .from('daily_health_logs')
        .select()
        .eq('pet_id', petId)
        .gte('logged_date', _formatDate(from))
        .order('logged_date', ascending: true);

    return (rows as List)
        .map((row) => DailyHealthLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<DailyHealthLog?> fetchTodayHealthLog(String petId) async {
    final now = DateTime.now();
    final today = _formatDate(DateTime(now.year, now.month, now.day));
    final row = await Supabase.instance.client
        .from('daily_health_logs')
        .select()
        .eq('pet_id', petId)
        .eq('logged_date', today)
        .maybeSingle();
    if (row == null) return null;
    return DailyHealthLog.fromMap(row);
  }

  Future<DailyHealthLog> upsertTodayHealthLog(
    String petId, {
    int? appetite,
    int? activity,
    int? sleep,
    int? digestion,
    required bool painSigns,
    String? memo,
  }) async {
    final now = DateTime.now();
    final today = _formatDate(DateTime(now.year, now.month, now.day));
    final payload = <String, dynamic>{
      'pet_id': petId,
      'logged_date': today,
      'appetite': appetite,
      'activity': activity,
      'sleep': sleep,
      'digestion': digestion,
      'pain_signs': painSigns,
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    // 멤버십 트리거가 걸린 테이블은 .insert().select() 체이닝의 RETURNING이 RLS에 막힐 수 있어
    // upsert 직후 별도 select로 다시 읽어옴.
    await Supabase.instance.client
        .from('daily_health_logs')
        .upsert(payload, onConflict: 'pet_id,logged_date');

    final row = await Supabase.instance.client
        .from('daily_health_logs')
        .select()
        .eq('pet_id', petId)
        .eq('logged_date', today)
        .single();

    return DailyHealthLog.fromMap(row);
  }

  Future<List<PoopLog>> fetchPoopLogs(
    String petId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var query = Supabase.instance.client
        .from('poop_logs')
        .select()
        .eq('pet_id', petId);
    if (from != null) {
      query = query.gte('logged_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lt('logged_at', to.toUtc().toIso8601String());
    }
    final rows = await query.order('logged_at', ascending: false);

    return (rows as List)
        .map((row) => PoopLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<PoopLog> addPoopLog(
    String petId, {
    required DateTime loggedAt,
    PoopShape? shape,
    PoopColor? color,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'shape': shape?.apiValue,
      'color': color?.apiValue,
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    final inserted = await Supabase.instance.client
        .from('poop_logs')
        .insert(payload)
        .select()
        .single();
    return PoopLog.fromMap(inserted);
  }

  Future<void> deletePoopLog(String id) async {
    await Supabase.instance.client.from('poop_logs').delete().eq('id', id);
  }

  Future<List<WaterLog>> fetchWaterLogs(
    String petId, {
    DateTime? from,
    DateTime? to,
  }) async {
    var query = Supabase.instance.client
        .from('water_logs')
        .select()
        .eq('pet_id', petId);
    if (from != null) {
      query = query.gte('logged_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lt('logged_at', to.toUtc().toIso8601String());
    }
    final rows = await query.order('logged_at', ascending: false);

    return (rows as List)
        .map((row) => WaterLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<WaterLog> addWaterLog(
    String petId, {
    required DateTime loggedAt,
    required int volumeMl,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'logged_at': loggedAt.toUtc().toIso8601String(),
      'volume_ml': volumeMl,
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    final inserted = await Supabase.instance.client
        .from('water_logs')
        .insert(payload)
        .select()
        .single();
    return WaterLog.fromMap(inserted);
  }

  Future<void> deleteWaterLog(String id) async {
    await Supabase.instance.client.from('water_logs').delete().eq('id', id);
  }

  Future<List<GroomingRecord>> fetchGroomingRecords(String petId) async {
    final rows = await Supabase.instance.client
        .from('grooming_records')
        .select()
        .eq('pet_id', petId)
        .order('groomed_at', ascending: false);

    return (rows as List)
        .map((row) => GroomingRecord.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<GroomingRecord> addGroomingRecord(
    String petId, {
    required DateTime groomedAt,
    String? salonName,
    List<GroomingService> services = const [],
    int? cost,
    DateTime? nextDueAt,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'groomed_at': _formatDate(groomedAt),
      'services': services.map((s) => s.apiValue).toList(),
    };
    if (salonName != null && salonName.isNotEmpty) {
      payload['salon_name'] = salonName;
    }
    if (cost != null) payload['cost'] = cost;
    if (nextDueAt != null) payload['next_due_at'] = _formatDate(nextDueAt);
    if (memo != null && memo.isNotEmpty) payload['memo'] = memo;

    final inserted = await Supabase.instance.client
        .from('grooming_records')
        .insert(payload)
        .select()
        .single();
    return GroomingRecord.fromMap(inserted);
  }

  Future<GroomingRecord> updateGroomingRecord(
    String id, {
    required DateTime groomedAt,
    String? salonName,
    List<GroomingService> services = const [],
    int? cost,
    DateTime? nextDueAt,
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'groomed_at': _formatDate(groomedAt),
      'salon_name': (salonName == null || salonName.isEmpty) ? null : salonName,
      'services': services.map((s) => s.apiValue).toList(),
      'cost': cost,
      'next_due_at': nextDueAt == null ? null : _formatDate(nextDueAt),
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    final updated = await Supabase.instance.client
        .from('grooming_records')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return GroomingRecord.fromMap(updated);
  }

  Future<void> deleteGroomingRecord(String id) async {
    await Supabase.instance.client
        .from('grooming_records')
        .delete()
        .eq('id', id);
  }

  Future<List<HeatCycle>> fetchHeatCycles(String petId) async {
    final rows = await Supabase.instance.client
        .from('heat_cycles')
        .select()
        .eq('pet_id', petId)
        .order('start_date', ascending: false);

    return (rows as List)
        .map((row) => HeatCycle.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<HeatCycle> addHeatCycle(
    String petId, {
    required DateTime startDate,
    DateTime? endDate,
    DateTime? nextExpected,
    List<HeatSymptom> symptoms = const [],
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'start_date': _formatDate(startDate),
      'symptoms': symptoms.map((s) => s.apiValue).toList(),
    };
    if (endDate != null) payload['end_date'] = _formatDate(endDate);
    if (nextExpected != null) {
      payload['next_expected'] = _formatDate(nextExpected);
    }
    if (memo != null && memo.isNotEmpty) payload['memo'] = memo;

    final inserted = await Supabase.instance.client
        .from('heat_cycles')
        .insert(payload)
        .select()
        .single();
    return HeatCycle.fromMap(inserted);
  }

  Future<HeatCycle> updateHeatCycle(
    String id, {
    required DateTime startDate,
    DateTime? endDate,
    DateTime? nextExpected,
    List<HeatSymptom> symptoms = const [],
    String? memo,
  }) async {
    final payload = <String, dynamic>{
      'start_date': _formatDate(startDate),
      'end_date': endDate == null ? null : _formatDate(endDate),
      'next_expected':
          nextExpected == null ? null : _formatDate(nextExpected),
      'symptoms': symptoms.map((s) => s.apiValue).toList(),
      'memo': (memo == null || memo.isEmpty) ? null : memo,
    };

    final updated = await Supabase.instance.client
        .from('heat_cycles')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return HeatCycle.fromMap(updated);
  }

  Future<void> deleteHeatCycle(String id) async {
    await Supabase.instance.client.from('heat_cycles').delete().eq('id', id);
  }

  Future<List<CageLog>> fetchCageLogs(
    String petId, {
    DateTime? from,
    DateTime? to,
    CageActivityType? type,
  }) async {
    var query = Supabase.instance.client
        .from('cage_logs')
        .select()
        .eq('pet_id', petId);
    if (type != null) {
      query = query.eq('type', type.apiValue);
    }
    if (from != null) {
      query = query.gte('logged_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lt('logged_at', to.toUtc().toIso8601String());
    }
    final rows = await query.order('logged_at', ascending: false);

    return (rows as List)
        .map((row) => CageLog.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<CageLog> addCageLog(
    String petId, {
    required CageActivityType type,
    DateTime? loggedAt,
    String? memo,
  }) async {
    final ts = (loggedAt ?? DateTime.now()).toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'pet_id': petId,
      'type': type.apiValue,
      'logged_at': ts,
    };
    if (memo != null && memo.isNotEmpty) payload['memo'] = memo;

    final inserted = await Supabase.instance.client
        .from('cage_logs')
        .insert(payload)
        .select()
        .single();
    return CageLog.fromMap(inserted);
  }

  Future<void> deleteCageLog(String id) async {
    await Supabase.instance.client.from('cage_logs').delete().eq('id', id);
  }

  Future<List<CageSchedule>> fetchCageSchedules(String petId) async {
    final rows = await Supabase.instance.client
        .from('cage_schedules')
        .select()
        .eq('pet_id', petId);

    return (rows as List)
        .map((row) => CageSchedule.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  // (pet_id, type) UNIQUE 가정. 동일한 type의 row가 있으면 갱신.
  Future<CageSchedule> upsertCageSchedule(
    String petId, {
    required CageActivityType type,
    required int intervalHours,
    required List<String> reminderTimes,
    required bool enabled,
  }) async {
    final payload = <String, dynamic>{
      'pet_id': petId,
      'type': type.apiValue,
      'interval_hours': intervalHours,
      'reminder_times': reminderTimes,
      'enabled': enabled,
    };

    await Supabase.instance.client
        .from('cage_schedules')
        .upsert(payload, onConflict: 'pet_id,type');

    final row = await Supabase.instance.client
        .from('cage_schedules')
        .select()
        .eq('pet_id', petId)
        .eq('type', type.apiValue)
        .single();
    return CageSchedule.fromMap(row);
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
