const int _baseTime = 1788278400000; // 2026-09-02 00:00 UTC

Map<String, dynamic> _demoNote(
  String id,
  String label,
  int color, {
  bool open = false,
  int hoursAgo = 0,
}) => {
  'id': id,
  'label': label,
  'color': color,
  'open': open,
  'updatedAt': _baseTime - hoursAgo * 3600000,
  'createdAt': _baseTime - (hoursAgo + 24) * 3600000,
};

final overviewDemoNotes = <Map<String, dynamic>>[
  _demoNote('aurora-meeting', '회의 · 오로라 출시 범위와 일정', 2, open: true),
  _demoNote('aurora-directive', '지시 · 결제 실패 로그를 금요일까지 확인', 1),
  _demoNote('aurora-work', '업무 · 온보딩 3단계 화면 구현', 0, hoursAgo: 3),
  _demoNote('aurora-risk', '업무 · 앱 심사 지연 대응안', 4, hoursAgo: 8),
  _demoNote('hiring-meeting', '회의 · 백엔드 면접 기준 합의', 3, hoursAgo: 28),
  _demoNote('hiring-task', '지시 · 지원자 피드백 오늘 전달', 5, hoursAgo: 30),
  _demoNote('personal-hospital', '개인 · 토요일 치과 예약 오전 11시', 1, hoursAgo: 5),
  _demoNote('personal-shopping', '개인 · 장보기 우유, 계란, 세제', 2, hoursAgo: 6),
  _demoNote('customer-call', '회의 · 환불 고객 인터뷰 요약', 0, hoursAgo: 12),
  _demoNote('refund-work', '업무 · 환불 정책 안내 문구 수정', 4, hoursAgo: 15),
  _demoNote('report-idea', '아이디어 · 완료 메모로 주간 보고 자동 초안', 3),
  _demoNote('review-idea', '아이디어 · 체크박스 기록으로 회고 만들기', 5, hoursAgo: 2),
  _demoNote('book', '개인 · 읽을 책: 일의 감각', 2, hoursAgo: 48),
];

const overviewDemoGroups = <Map<String, dynamic>>[
  {
    'id': 'aurora',
    'name': '오로라 출시 준비',
    'position': 0,
    'collapsed': false,
    'memberIds': [
      'aurora-meeting',
      'aurora-directive',
      'aurora-work',
      'aurora-risk',
    ],
  },
  {
    'id': 'hiring',
    'name': '채용 프로세스 개선',
    'position': 1,
    'collapsed': true,
    'memberIds': ['hiring-meeting', 'hiring-task'],
  },
  {
    'id': 'personal',
    'name': '개인 생활',
    'position': 2,
    'collapsed': false,
    'memberIds': ['personal-hospital', 'personal-shopping'],
  },
];

const overviewDemoEdges = <Map<String, dynamic>>[
  {'a': 'customer-call', 'b': 'refund-work'},
];

const overviewDemoSuggestions = <Map<String, dynamic>>[
  {
    'ids': ['report-idea', 'review-idea'],
    'score': 0.84,
    'title': '주간 보고 · 회고',
    'reasons': ['‘아이디어’ 키워드가 겹쳐요', '표현은 달라도 의미가 가까워요'],
  },
];
