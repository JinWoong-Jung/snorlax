# 잠만보 플랫폼과 검증 범위 결정

최초 결정 2026-11-02, 검증 범위 갱신 2026-11-07.

## 제품 구조

잠만보는 SwiftUI 기반 iPhone 앱과 Apple Watch 동반 앱으로 구성한다. 수면 조회·분석·질문·목표·PDF는 iPhone이 담당하고, Watch는 기분·스트레스·카페인을 빠르게 입력한다. Watch 입력은 WatchConnectivity로 페어링된 iPhone에 비동기 전달한다.

HealthKit 수면 기록 조회가 핵심이므로 네이티브 구조를 유지한다. Windows에서 GitHub 소스를 읽고 AI로 검토할 수 있으나 iOS 빌드·설치는 macOS와 Xcode를 사용한다. HTML 파일은 이전 아이디어 참고본이다.

## 첫 사용자 검증 범위

사용자의 현재 요청에 따라 첫 회차는 iPhone 앱 중심으로 진행한다. Watch는 iPhone 기능을 쓰기 위한 필수 장비가 아니다. Watch 기기 검증을 마친 경우에만 T2b 선택 과업을 포함한다. 연결되지 않으면 실행 불가로 기록하며 iPhone 핵심 과업의 완료율에 섞지 않는다.

현재 프로젝트는 Watch 앱을 iPhone 타깃에 임베드한다. iPhone 중심 테스트라는 결정은 이 타깃을 삭제했다는 뜻이 아니다. 완전히 iPhone 전용인 배포 파일이 필요해지면 별도 타깃·스킴 구성과 배포 서명을 점검한다.

## 구현된 경계

| 영역 | 현재 책임 |
|---|---|
| 수면 | SleepStore가 HealthKit을 읽고 종료일 기준으로 정규화. 상세 단계와 미분류를 구분하고 최근 7일 표시. |
| 체크인 | CheckInStore가 폰 입력과 Watch 수신을 저장. WatchSessionStore는 최대 30건 대기 후 전송 예약. |
| 질문 | AnalysisService가 규칙 계산. 샘플과 개인 습관 비교는 제외하고 실제 조건별 최소 2일 요구. |
| 계획 | PlanStore가 목표와 수동 일정 저장. 취침 시각은 기상 목표에서 목표 수면 분을 차감. |
| 요약 | ReportSummary가 질문·요약·PDF 기간을 공유. ReportExportStore가 스냅샷 무효화, ReportPDFGenerator가 생성, PDFKit이 내부 미리보기. |
| 제외 | 서버, 계정, LLM API, 캘린더 동기화, 주간 일정 최적화, 알람·컴플리케이션 |

## 검증 상태와 다음 확인

사용자 보고로 iPhone 앱 실행을 확인했다. 서명 없는 iPhone·Watch 빌드와 UI 없는 계산 검사는 통과했다. 실제 HealthKit의 단계와 출처 중첩, Watch 설치·전달·재연결, PDF 공유 취소, 키보드와 접근성은 기기에서 확인한다.

무료 Personal Team을 통한 본인 기기 테스트와 외부 사람에게 설치 링크를 보내는 배포는 조건이 다르다. 실제 사용자에게 어떤 기기에서 사용 기회를 제공할지 먼저 정하고, TestFlight 등 배포 계정·비용은 확정 후 기록한다. 현재 외부 배포 또는 고객 테스트가 완료된 것으로 표시하지 않는다.
