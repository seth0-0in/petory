# 🐾 Petory - 반려동물 다이어리 앱

<p align="center">
  <img src="assets/icon.png" width="120" alt="Petory 아이콘"/>
</p>

<p align="center">
  <strong>반려동물과의 모든 순간을 기록하고, 건강을 관리하는 올인원 다이어리 앱</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.44.1-02569B?style=flat-square&logo=flutter"/>
  <img src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?style=flat-square&logo=supabase"/>
  <img src="https://img.shields.io/badge/Platform-Android-green?style=flat-square&logo=android"/>
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square"/>
</p>

---

## 📱 스크린샷

| 홈 화면 | 캘린더 | 건강 기록 | 케어 팁 |
|--------|--------|----------|--------|
| <img src="https://github.com/seth0-0in/petory/raw/main/screenshots/홈화면.png" width="180"/> | <img src="https://github.com/seth0-0in/petory/raw/main/screenshots/캘린더.png" width="180"/> | <img src="https://github.com/seth0-0in/petory/raw/main/screenshots/체중그래프.png" width="180"/> | <img src="https://github.com/seth0-0in/petory/raw/main/screenshots/케어팁.png" width="180"/> |

---

## ✨ 주요 기능

### 📖 사진 일기
- 매일의 소중한 순간을 사진과 함께 기록
- 타임라인으로 추억을 한눈에
- 날짜·키워드 검색 및 날짜 범위 필터

### ❤️ 건강 관리
- **체중** — 그래프로 변화 추이 확인
- **예방접종** — 일정 관리 및 기기 알림
- **투약/영양제** — 복용 스케줄 + 시간 알림
- **병원 기록** — 증상·진단·비용 기록

### 🌿 케어 팁
- 수의학 가이드라인(AAHA/AAFP) 기반 정보
- 나이·종·품종별 맞춤 케어 정보 제공

### 📅 캘린더
- 기록·접종·기념일을 달력으로 한눈에
- 이벤트 탭 시 관련 화면으로 이동

### 🎉 기념일 & 마일스톤
- 입양 D+100/200/... 자동 계산
- 입양 기념일·생일 알림

### 👨‍👩‍👧 가족 공유
- 초대 코드로 가족과 함께 기록
- 실시간 데이터 동기화

### 🏥 내 주변 동물병원 찾기
- 네이버 지도·카카오맵·구글 지도 연동

### ⚙️ 기타
- 테마 색상 변경 (6가지)
- 다크 모드 지원
- 데이터 내보내기 (CSV/JSON)
- 게스트로 바로 시작 (회원가입 불필요)
- 계정 생성으로 기기 변경 시 데이터 보존

---

## 🛠 기술 스택

| 분류 | 기술 |
|------|------|
| **Frontend** | Flutter 3.44.1, Dart |
| **Backend** | Supabase (PostgreSQL, Auth, Storage) |
| **상태 관리** | ValueNotifier |
| **차트** | fl_chart |
| **지도** | url_launcher (딥링크) |
| **알림** | flutter_local_notifications |
| **인증** | Supabase Auth (익명 + 이메일) |
| **스토리지** | Supabase Storage |

---

## 🚀 실행 방법

### 사전 준비
- Flutter SDK 3.44.1 이상
- Android Studio (에뮬레이터용)
- Supabase 프로젝트

### 환경 변수 설정
`lib/supabase_config.dart` 파일에 Supabase 프로젝트 URL과 키를 설정하세요.

```dart
const supabaseUrl = 'YOUR_SUPABASE_URL';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

### 실행

```bash
# 의존성 설치
flutter pub get

# 웹으로 실행
flutter run -d chrome --web-port=8080

# 안드로이드 에뮬레이터로 실행
flutter run

# 릴리즈 APK 빌드
flutter build apk --release
```

---

## 🗄 데이터베이스 구조

```
auth.users
├── pets (반려동물)
│   ├── pet_members (멤버십/가족 공유)
│   ├── logs (사진 일기)
│   ├── weight_records (체중)
│   ├── vaccinations (예방접종)
│   ├── medications (투약)
│   ├── vet_visits (병원 기록)
│   ├── milestones (마일스톤)
│   └── pet_invites (초대 코드)
├── feedback (피드백)
└── care_tips (케어 팁, 공개)
```

---

## 📁 프로젝트 구조

```
lib/
├── main.dart                 # 앱 진입점
├── supabase_config.dart      # Supabase 설정
├── models/                   # 데이터 모델
├── services/                 # 비즈니스 로직
│   ├── auth_service.dart
│   ├── supabase_service.dart
│   └── notification_service.dart
└── screens/                  # UI 화면
    ├── home_screen.dart
    ├── health_screen.dart
    ├── calendar_screen.dart
    ├── care_tips_screen.dart
    └── ...
```

---

## 🔒 개인정보처리방침

[개인정보처리방침 보기](https://seth0-0in.github.io/petory-privacy/privacy_policy.html)

---

## 👨‍💻 개발자

**TrueWorld Studio**
- GitHub: [@seth0-0in](https://github.com/seth0-0in)

---

## 📄 라이선스

MIT License © 2026 TrueWorld Studio 