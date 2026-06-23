import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

const String _kSearchQuery = '반려동물장례식장';

enum _MapApp { google, kakao, naver }

Future<void> showNearbyFuneralSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _NearbyFuneralSheet(),
  );
}

class _NearbyFuneralSheet extends StatelessWidget {
  const _NearbyFuneralSheet();

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
    final q = Uri.encodeComponent(_kSearchQuery);
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
          content: Text('위치를 허용하면 더 가까운 곳을 찾을 수 있어요.'),
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
              '현재 위치 주변의 반려동물 장례식장을 찾아드려요.',
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
