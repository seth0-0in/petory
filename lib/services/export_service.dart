import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../models/log_entry.dart';
import '../models/medication.dart';
import '../models/milestone.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet_visit.dart';
import '../models/weight_record.dart';
import 'supabase_service.dart';

enum ExportFormat { csv, json }

extension ExportFormatX on ExportFormat {
  String get extension => this == ExportFormat.csv ? 'csv' : 'json';
  String get mimeType =>
      this == ExportFormat.csv ? 'text/csv' : 'application/json';
}

class ExportBundle {
  final String filename;
  final Uint8List bytes;
  final String mimeType;

  const ExportBundle({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });
}

class ExportService {
  ExportService({SupabaseService? service})
      : _service = service ?? SupabaseService();

  final SupabaseService _service;

  Future<ExportBundle> exportPet(Pet pet, ExportFormat format) async {
    final results = await Future.wait([
      _service.fetchLogs(pet.id),
      _service.fetchWeights(pet.id),
      _service.fetchVaccinations(pet.id),
      _service.fetchMedications(pet.id),
      _service.fetchVetVisits(pet.id),
      _service.fetchMilestones(pet.id),
    ]);

    final logs = results[0] as List<LogEntry>;
    final weights = results[1] as List<WeightRecord>;
    final vaccinations = results[2] as List<Vaccination>;
    final medications = results[3] as List<Medication>;
    final vetVisits = results[4] as List<VetVisit>;
    final milestones = results[5] as List<Milestone>;

    final today = DateFormat('yyyyMMdd').format(DateTime.now());
    final safeName = _sanitizeFileName(pet.name);
    final filename = 'pet_diary_${safeName}_$today.${format.extension}';

    final text = switch (format) {
      ExportFormat.csv => _buildCsv(
          pet,
          logs: logs,
          weights: weights,
          vaccinations: vaccinations,
          medications: medications,
          vetVisits: vetVisits,
          milestones: milestones,
        ),
      ExportFormat.json => _buildJson(
          pet,
          logs: logs,
          weights: weights,
          vaccinations: vaccinations,
          medications: medications,
          vetVisits: vetVisits,
          milestones: milestones,
        ),
    };

    final bytes = Uint8List.fromList(utf8.encode(text));
    return ExportBundle(
      filename: filename,
      bytes: bytes,
      mimeType: format.mimeType,
    );
  }

  String _buildCsv(
    Pet pet, {
    required List<LogEntry> logs,
    required List<WeightRecord> weights,
    required List<Vaccination> vaccinations,
    required List<Medication> medications,
    required List<VetVisit> vetVisits,
    required List<Milestone> milestones,
  }) {
    const encoder = CsvEncoder();

    final sections = <List<List<dynamic>>>[
      [
        ['## 기본 정보'],
        ['이름', '종', '품종', '생일', '입양일'],
        [
          pet.name,
          pet.species,
          pet.breed ?? '',
          _fmtDate(pet.birthday),
          _fmtDate(pet.adoptionDate),
        ],
      ],
      [
        ['## 사진 일기'],
        ['날짜', '내용', '사진URL'],
        ...logs.map((l) => [_fmtDate(l.createdAt), l.content, l.photoUrl ?? '']),
      ],
      [
        ['## 체중 기록'],
        ['날짜', '체중(kg)'],
        ...weights.map((w) => [_fmtDate(w.measuredAt), w.weightKg]),
      ],
      [
        ['## 예방접종'],
        ['이름', '접종일', '다음 예정일', '메모'],
        ...vaccinations.map((v) => [
              v.name,
              _fmtDate(v.administeredAt),
              _fmtDate(v.nextDueAt),
              v.memo ?? '',
            ]),
      ],
      [
        ['## 투약'],
        ['이름', '종류', '용량', '횟수', '시작일', '종료일', '메모'],
        ...medications.map((m) => [
              m.name,
              m.kind.label,
              m.dosage ?? '',
              m.frequency ?? '',
              _fmtDate(m.startDate),
              _fmtDate(m.endDate),
              m.memo ?? '',
            ]),
      ],
      [
        ['## 병원 기록'],
        ['방문일', '병원명', '사유', '진단', '처치', '비용', '메모'],
        ...vetVisits.map((v) => [
              _fmtDate(v.visitedAt),
              v.hospital ?? '',
              v.reason ?? '',
              v.diagnosis ?? '',
              v.treatment ?? '',
              v.cost ?? '',
              v.memo ?? '',
            ]),
      ],
      [
        ['## 마일스톤'],
        ['제목', '날짜', '메모'],
        ...milestones.map(
          (m) => [m.title, _fmtDate(m.achievedAt), m.memo ?? ''],
        ),
      ],
    ];

    final buffer = StringBuffer();
    buffer.write('﻿'); // UTF-8 BOM so Excel renders Korean correctly.
    for (var i = 0; i < sections.length; i++) {
      if (i > 0) buffer.write('\r\n');
      buffer.write(encoder.convert(sections[i]));
      buffer.write('\r\n');
    }
    return buffer.toString();
  }

  String _buildJson(
    Pet pet, {
    required List<LogEntry> logs,
    required List<WeightRecord> weights,
    required List<Vaccination> vaccinations,
    required List<Medication> medications,
    required List<VetVisit> vetVisits,
    required List<Milestone> milestones,
  }) {
    final data = <String, dynamic>{
      'pet': {
        'name': pet.name,
        'species': pet.species,
        'breed': pet.breed,
        'birthday': _fmtDateOrNull(pet.birthday),
        'adoption_date': _fmtDateOrNull(pet.adoptionDate),
      },
      'logs': logs
          .map((l) => {
                'date': _fmtDateOrNull(l.createdAt),
                'content': l.content,
                'photo_url': l.photoUrl,
              })
          .toList(),
      'weights': weights
          .map((w) => {
                'date': _fmtDateOrNull(w.measuredAt),
                'weight_kg': w.weightKg,
              })
          .toList(),
      'vaccinations': vaccinations
          .map((v) => {
                'name': v.name,
                'administered_at': _fmtDateOrNull(v.administeredAt),
                'next_due_at': _fmtDateOrNull(v.nextDueAt),
                'memo': v.memo,
              })
          .toList(),
      'medications': medications
          .map((m) => {
                'name': m.name,
                'kind': m.kind.label,
                'dosage': m.dosage,
                'frequency': m.frequency,
                'start_date': _fmtDateOrNull(m.startDate),
                'end_date': _fmtDateOrNull(m.endDate),
                'memo': m.memo,
              })
          .toList(),
      'vet_visits': vetVisits
          .map((v) => {
                'visited_at': _fmtDateOrNull(v.visitedAt),
                'hospital': v.hospital,
                'reason': v.reason,
                'diagnosis': v.diagnosis,
                'treatment': v.treatment,
                'cost': v.cost,
                'memo': v.memo,
              })
          .toList(),
      'milestones': milestones
          .map((m) => {
                'title': m.title,
                'date': _fmtDateOrNull(m.achievedAt),
                'memo': m.memo,
              })
          .toList(),
      'exported_at': DateTime.now().toIso8601String(),
      'version': 1,
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(data);
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String? _fmtDateOrNull(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  String _sanitizeFileName(String raw) {
    final cleaned =
        raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();
    return cleaned.isEmpty ? 'pet' : cleaned;
  }
}
