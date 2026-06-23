import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

// 위치 권한과 딥링크 패턴은 nearby_vet_sheet.dart 와 동일하게 구성.
// Android 권한(ACCESS_FINE_LOCATION/ACCESS_COARSE_LOCATION)도 거기서 함께 처리됨.

enum _PlaceCategory { cafe, restaurant, lodging, shopping, park, custom }

enum _MapApp { google, kakao, naver }

class _PlaceMeta {
  final String emoji;
  final String label;
  final String subtitle;
  final String keyword;

  const _PlaceMeta({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.keyword,
  });
}

const Map<_PlaceCategory, _PlaceMeta> _kPlaceMeta = {
  _PlaceCategory.cafe: _PlaceMeta(
    emoji: '☕',
    label: '펫 카페',
    subtitle: '반려동물과 함께 갈 수 있는 카페',
    keyword: '펫카페',
  ),
  _PlaceCategory.restaurant: _PlaceMeta(
    emoji: '🍽️',
    label: '반려동물 동반 식당',
    subtitle: '반려동물 동반 가능한 식당',
    keyword: '반려동물동반식당',
  ),
  _PlaceCategory.lodging: _PlaceMeta(
    emoji: '🏨',
    label: '반려동물 동반 숙소',
    subtitle: '함께 묵을 수 있는 호텔·펜션',
    keyword: '반려동물동반숙소',
  ),
  _PlaceCategory.shopping: _PlaceMeta(
    emoji: '🛍️',
    label: '펫 동반 쇼핑몰/마트',
    subtitle: '반려동물과 입장 가능한 매장',
    keyword: '펫동반쇼핑',
  ),
  _PlaceCategory.park: _PlaceMeta(
    emoji: '🌳',
    label: '반려동물 동반 공원',
    subtitle: '함께 산책할 수 있는 공원',
    keyword: '반려동물공원',
  ),
  _PlaceCategory.custom: _PlaceMeta(
    emoji: '🔍',
    label: '직접 검색',
    subtitle: '원하는 키워드로 직접 찾기',
    keyword: '',
  ),
};

Future<void> showPetFriendlyPlacesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _CategoryPickerSheet(),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  const _CategoryPickerSheet();

  Future<void> _onPickCategory(
    BuildContext context,
    _PlaceCategory category,
  ) async {
    Navigator.pop(context);
    String? keyword = _kPlaceMeta[category]!.keyword;
    if (category == _PlaceCategory.custom) {
      keyword = await _promptCustomKeyword(context);
      if (keyword == null || keyword.isEmpty) return;
    }
    if (!context.mounted) return;
    await _showMapAppSheet(context, keyword);
  }

  Future<String?> _promptCustomKeyword(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('검색어 입력'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '예: 애견 운동장, 펫프렌들리 펜션',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) =>
                Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: const Text('검색'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('장소 카테고리', style: textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '반려동물과 함께 갈 만한 곳을 지도 앱으로 찾아드려요.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          for (final entry in _kPlaceMeta.entries)
            _CategoryTile(
              emoji: entry.value.emoji,
              title: entry.value.label,
              subtitle: entry.value.subtitle,
              colorScheme: colorScheme,
              textTheme: textTheme,
              onTap: () => _onPickCategory(context, entry.key),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Future<void> _showMapAppSheet(BuildContext context, String keyword) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _MapAppPickerSheet(keyword: keyword),
  );
}

class _MapAppPickerSheet extends StatelessWidget {
  final String keyword;
  const _MapAppPickerSheet({required this.keyword});

  Future<Position?> _tryGetCoords() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Uri _urlFor(_MapApp app, Position? pos) {
    final q = Uri.encodeComponent(keyword);
    switch (app) {
      case _MapApp.google:
        if (pos != null) {
          return Uri.parse(
            'https://www.google.com/maps/search/$q/@${pos.latitude},${pos.longitude},15z',
          );
        }
        return Uri.parse('https://www.google.com/maps/search/$q');
      case _MapApp.kakao:
        return Uri.parse('https://map.kakao.com/?q=$q');
      case _MapApp.naver:
        return Uri.parse('https://map.naver.com/v5/search/$q');
    }
  }

  Future<void> _handle(BuildContext context, _MapApp app) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    final pos = await _tryGetCoords();
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('위치를 허용하면 더 가까운 장소를 찾을 수 있어요.'),
        ),
      );
    }

    final url = _urlFor(app, pos);
    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('지도 앱을 열지 못했어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: Text('지도 앱 선택', style: textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              '"$keyword" 키워드로 검색해요.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          _MapTile(
            icon: Icons.travel_explore,
            title: '구글 지도',
            subtitle: '현재 좌표 기준 주변 검색',
            colorScheme: colorScheme,
            onTap: () => _handle(context, _MapApp.google),
          ),
          _MapTile(
            icon: Icons.map_outlined,
            title: '카카오맵',
            subtitle: '국내 지도 서비스',
            colorScheme: colorScheme,
            onTap: () => _handle(context, _MapApp.kakao),
          ),
          _MapTile(
            icon: Icons.public,
            title: '네이버 지도',
            subtitle: '국내 지도 서비스',
            colorScheme: colorScheme,
            onTap: () => _handle(context, _MapApp.naver),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _MapTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _MapTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colorScheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
