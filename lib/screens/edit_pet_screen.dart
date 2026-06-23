import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  final ImagePicker _picker = ImagePicker();
  late final TextEditingController _nameController;
  late final TextEditingController _breedCustomController;
  late String _species;
  String? _breedSelection; // null=선택 안 함, _customBreedSentinel=직접 입력, 그 외=프리셋 값
  late DateTime _adoptionDate;
  DateTime? _birthday;
  bool _isNeutered = false;
  bool _isRainbowBridge = false;
  bool _saving = false;

  // 프로필 사진 상태.
  // - _profileImageUrl: 서버에 저장된 URL (편집 모드 초기값 또는 업로드 후 갱신).
  // - _newProfileBytes: 새로 선택했지만 아직 업로드 안 한 로컬 바이트 (신규 등록 케이스).
  String? _profileImageUrl;
  Uint8List? _newProfileBytes;
  String? _newProfileMime;
  String? _newProfileExt;
  bool _uploadingProfile = false;

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
      _isNeutered = pet.isNeutered;
      _isRainbowBridge = pet.isRainbowBridge;
      _profileImageUrl = pet.profileImageUrl;
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

  Future<void> _onToggleRainbowBridge(bool value) async {
    if (_saving) return;
    if (!value) {
      setState(() {
        _isRainbowBridge = false;
      });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final purple = Colors.deepPurple.shade300;
        return AlertDialog(
          icon: Icon(Icons.favorite, color: purple, size: 32),
          title: const Text('🌈 무지개다리로 표시'),
          content: const Text(
            '이 아이를 추모 상태로 전환할게요.\n'
            '기록은 그대로 보존되고, 홈에서 부드럽게 표시돼요.\n\n'
            '언제든 다시 끌 수 있어요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('추모로 전환'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      setState(() {
        _isRainbowBridge = true;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    if (_saving || _uploadingProfile) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final mime = picked.mimeType ?? 'image/jpeg';
    final ext = _extFromName(picked.name) ?? 'jpg';

    // 편집 모드면 즉시 업로드해서 단독 갱신. 신규 등록이면 저장 시점에 업로드.
    if (_isEdit) {
      setState(() {
        _uploadingProfile = true;
      });
      try {
        final url = await _service.uploadPetProfileImage(
          bytes,
          petId: widget.pet!.id,
          contentType: mime,
          extension: ext,
        );
        await _service.updatePetProfileImage(widget.pet!.id, url);
        if (!mounted) return;
        setState(() {
          _profileImageUrl = url;
          _newProfileBytes = null;
          _uploadingProfile = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _uploadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 사진 업로드 실패: $e')),
        );
      }
    } else {
      setState(() {
        _newProfileBytes = bytes;
        _newProfileMime = mime;
        _newProfileExt = ext;
      });
    }
  }

  Future<void> _removeProfileImage() async {
    if (_saving || _uploadingProfile) return;
    if (_isEdit) {
      setState(() {
        _uploadingProfile = true;
      });
      try {
        await _service.updatePetProfileImage(widget.pet!.id, null);
        if (!mounted) return;
        setState(() {
          _profileImageUrl = null;
          _newProfileBytes = null;
          _uploadingProfile = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _uploadingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 사진 제거 실패: $e')),
        );
      }
    } else {
      setState(() {
        _newProfileBytes = null;
      });
    }
  }

  String? _extFromName(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0 || i == name.length - 1) return null;
    return name.substring(i + 1).toLowerCase();
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
          isNeutered: _isNeutered,
          isRainbowBridge: _isRainbowBridge,
          profileImageUrl: _profileImageUrl,
        );
      } else {
        // 신규 등록: 펫을 먼저 만들고, 선택한 사진이 있으면 업로드 후 갱신.
        final created = await _service.createPet(
          name: name,
          species: _species,
          breed: breed,
          adoptionDate: _adoptionDate,
          birthday: _birthday,
          isNeutered: _isNeutered,
          isRainbowBridge: _isRainbowBridge,
        );
        Pet finalPet = created;
        final bytes = _newProfileBytes;
        if (bytes != null) {
          try {
            final url = await _service.uploadPetProfileImage(
              bytes,
              petId: created.id,
              contentType: _newProfileMime ?? 'image/jpeg',
              extension: _newProfileExt ?? 'jpg',
            );
            finalPet = await _service.updatePetProfileImage(created.id, url);
          } catch (_) {
            // 프로필 업로드 실패는 등록 자체를 막지 않음.
          }
        }
        result = finalPet;
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
            Center(
              child: _ProfileImagePicker(
                imageUrl: _profileImageUrl,
                pendingBytes: _newProfileBytes,
                name: _nameController.text,
                uploading: _uploadingProfile,
                colorScheme: colorScheme,
                onPick: _pickProfileImage,
                onRemove:
                    (_profileImageUrl != null || _newProfileBytes != null)
                        ? _removeProfileImage
                        : null,
              ),
            ),
            const SizedBox(height: 20),
            Text('이름', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              onChanged: (_) => setState(() {}),
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.healing_outlined,
                    color: colorScheme.primary,
                  ),
                  title: const Text('중성화 완료'),
                  subtitle: const Text('중성화한 경우 발정기 관련 기능이 숨겨져요'),
                  value: _isNeutered,
                  onChanged: _saving
                      ? null
                      : (v) {
                          setState(() {
                            _isNeutered = v;
                          });
                        },
                ),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _isRainbowBridge
                      ? Colors.deepPurple.withValues(alpha: 0.08)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: _isRainbowBridge
                      ? Border.all(
                          color: Colors.deepPurple.shade200,
                          width: 1,
                        )
                      : null,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.favorite_outline,
                      color: Colors.deepPurple.shade400,
                    ),
                    title: const Text('🌈 무지개다리'),
                    subtitle: const Text(
                      '하늘나라로 떠난 아이를 추모 상태로 보존해요',
                    ),
                    activeThumbColor: Colors.deepPurple.shade300,
                    value: _isRainbowBridge,
                    onChanged: _saving ? null : _onToggleRainbowBridge,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfileImagePicker extends StatelessWidget {
  final String? imageUrl;
  final Uint8List? pendingBytes;
  final String name;
  final bool uploading;
  final ColorScheme colorScheme;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  const _ProfileImagePicker({
    required this.imageUrl,
    required this.pendingBytes,
    required this.name,
    required this.uploading,
    required this.colorScheme,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '🐾' : name.characters.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: ClipOval(
              child: Container(
                color: colorScheme.primaryContainer,
                alignment: Alignment.center,
                child: pendingBytes != null
                    ? Image.memory(
                        pendingBytes!,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                      )
                    : (imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            width: 120,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _InitialAvatar(
                              text: initial,
                              colorScheme: colorScheme,
                            ),
                          )
                        : _InitialAvatar(
                            text: initial,
                            colorScheme: colorScheme,
                          )),
              ),
            ),
          ),
        ),
        if (uploading)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.35),
              ),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Positioned(
          right: -2,
          bottom: -2,
          child: Material(
            color: colorScheme.primary,
            shape: const CircleBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: uploading ? null : onPick,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ),
        if (onRemove != null && !uploading)
          Positioned(
            left: -2,
            bottom: -2,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              elevation: 1,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  final String text;
  final ColorScheme colorScheme;
  const _InitialAvatar({required this.text, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      color: colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
