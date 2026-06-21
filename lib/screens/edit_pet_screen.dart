import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/supabase_service.dart';

class EditPetScreen extends StatefulWidget {
  final Pet? pet;

  const EditPetScreen({super.key, this.pet});

  @override
  State<EditPetScreen> createState() => _EditPetScreenState();
}

class _EditPetScreenState extends State<EditPetScreen> {
  static const List<String> _speciesOptions = ['강아지', '고양이', '기타'];

  static const String _customBreedSentinel = '__custom__';

  static const List<String> _dogBreeds = [
    '말티즈',
    '푸들',
    '토이푸들',
    '포메라니안',
    '시츄',
    '비숑 프리제',
    '치와와',
    '요크셔테리어',
    '닥스훈트',
    '진돗개',
    '시바견',
    '웰시코기',
    '골든 리트리버',
    '래브라도 리트리버',
    '보더콜리',
    '프렌치불독',
    '슈나우저',
    '사모예드',
    '비글',
    '코카스파니엘',
    '믹스/기타',
  ];

  static const List<String> _catBreeds = [
    '코리안숏헤어',
    '아메리칸숏헤어',
    '페르시안',
    '엑조틱숏헤어',
    '스코티시폴드',
    '메인쿤',
    '브리티시숏헤어',
    '랙돌',
    '벵갈',
    '러시안블루',
    '먼치킨',
    '노르웨이숲',
    '샴',
    '아비시니안',
    '터키시앙고라',
    '믹스/기타',
  ];

  static const List<String> _otherBreeds = [
    '토끼',
    '햄스터',
    '기니피그',
    '고슴도치',
    '페럿',
    '친칠라',
    '앵무새/조류',
    '거북이/파충류',
    '물고기',
    '기타',
  ];

  final SupabaseService _service = SupabaseService();
  late final TextEditingController _nameController;
  late final TextEditingController _breedCustomController;
  late String _species;
  String? _breedSelection; // null=선택 안 함, _customBreedSentinel=직접 입력, 그 외=프리셋 값
  late DateTime _adoptionDate;
  DateTime? _birthday;
  bool _saving = false;

  bool get _isEdit => widget.pet != null;

  List<String> _breedsFor(String species) {
    switch (species) {
      case '강아지':
        return _dogBreeds;
      case '고양이':
        return _catBreeds;
      default:
        return _otherBreeds;
    }
  }

  String get _breedLabel =>
      _species == '기타' ? '동물 종류 (선택)' : '품종 (선택)';

  String get _customBreedHint =>
      _species == '기타' ? '예: 슈가글라이더' : '예: 시바이누';

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    _nameController = TextEditingController(text: pet?.name ?? '');

    if (pet != null) {
      _species = _speciesOptions.contains(pet.species) ? pet.species : '기타';
      _adoptionDate = pet.adoptionDate;
      _birthday = pet.birthday;
    } else {
      _species = _speciesOptions.first;
      final now = DateTime.now();
      _adoptionDate = DateTime(now.year, now.month, now.day);
    }

    final existingBreed = pet?.breed;
    if (existingBreed != null && existingBreed.isNotEmpty) {
      if (_breedsFor(_species).contains(existingBreed)) {
        _breedSelection = existingBreed;
        _breedCustomController = TextEditingController();
      } else {
        _breedSelection = _customBreedSentinel;
        _breedCustomController = TextEditingController(text: existingBreed);
      }
    } else {
      _breedSelection = null;
      _breedCustomController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedCustomController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y년 $m월 $d일';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _adoptionDate.isAfter(today) ? today : _adoptionDate,
      firstDate: DateTime(1990),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _adoptionDate = picked;
    });
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _birthday ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(1990),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _birthday = picked;
    });
  }

  String? _resolveBreed() {
    final sel = _breedSelection;
    if (sel == null) return null;
    if (sel == _customBreedSentinel) {
      final v = _breedCustomController.text.trim();
      return v.isEmpty ? null : v;
    }
    return sel;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이름을 입력해 주세요.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final breed = _resolveBreed();
    try {
      final Pet result;
      if (_isEdit) {
        result = await _service.updatePet(
          id: widget.pet!.id,
          name: name,
          species: _species,
          breed: breed,
          adoptionDate: _adoptionDate,
          birthday: _birthday,
        );
      } else {
        result = await _service.createPet(
          name: name,
          species: _species,
          breed: breed,
          adoptionDate: _adoptionDate,
          birthday: _birthday,
        );
      }
      if (!mounted) return;
      Navigator.pop<Pet>(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? '내 펫 정보' : '새 반려동물 등록'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('이름', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '반려동물의 이름',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),
            Text('종', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: _speciesOptions
                  .map(
                    (option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                if (value == _species) return;
                setState(() {
                  _species = value;
                  _breedSelection = null;
                  _breedCustomController.clear();
                });
              },
            ),
            const SizedBox(height: 20),
            Text(_breedLabel, style: textTheme.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _breedSelection,
              isExpanded: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: _species == '기타' ? '동물 종류 선택' : '품종 선택',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('선택 안 함'),
                ),
                for (final breed in _breedsFor(_species))
                  DropdownMenuItem<String?>(
                    value: breed,
                    child: Text(breed),
                  ),
                const DropdownMenuItem<String?>(
                  value: _customBreedSentinel,
                  child: Text('직접 입력'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _breedSelection = value;
                  if (value != _customBreedSentinel) {
                    _breedCustomController.clear();
                  }
                });
              },
            ),
            if (_breedSelection == _customBreedSentinel) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _breedCustomController,
                autofocus: !_isEdit,
                decoration: InputDecoration(
                  hintText: _customBreedHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 20),
            Text('입양일', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _formatDate(_adoptionDate),
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('생일 (선택)', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickBirthday,
                    borderRadius: BorderRadius.circular(4),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.cake_outlined),
                      ),
                      child: Text(
                        _birthday == null ? '생일 선택' : _formatDate(_birthday!),
                        style: textTheme.bodyLarge?.copyWith(
                          color: _birthday == null
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_birthday != null)
                  IconButton(
                    tooltip: '생일 지우기',
                    icon: Icon(
                      Icons.close,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() => _birthday = null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
