# 잠만보 Jammanbo

HealthKit 수면 기록과 생활습관 체크인을 함께 살펴보는 iPhone 앱과 Apple Watch 동반 앱 프로토타입입니다. 최근 기록의 날짜와 출처를 확인하고, 목표 취침 시각을 계산하며, 상담에 참고할 요약 PDF를 만들 수 있습니다.

첫 사용자 테스트는 iPhone 중심으로 진행합니다. Apple Watch 앱은 선택적으로 체크인을 입력하는 동반 앱이며, iPhone 핵심 기능에 Watch가 필수는 아닙니다. 현재 Xcode 프로젝트에는 Watch 앱이 함께 포함됩니다.

## 구현된 기능

- **수면 조회:** HealthKit 구간의 겹침을 제거하고 세션의 기상일로 집계합니다. 최근 7일 전체 목록과 일별 상세를 제공하며 단계 미제공과 0분을 구분합니다. 연결 요청 후에는 앱 복귀·기록 변경 시 다시 조회합니다.
- **체크인:** 기분·스트레스·카페인·전날 운동(있음/없음/미기록)을 iPhone·Watch에서 입력하고 기록 시각순 최근 30건을 보관합니다. 전체 이력에서 수정·삭제할 수 있습니다. Watch는 iPhone 저장 확인까지 대기열을 유지하고 오류·미확인 항목을 재시도합니다.
- **질문:** 평균 수면, 깊은 잠·렘수면, 같은 날짜의 생활습관 비교를 기기 내 규칙으로 계산하고 근거를 표시합니다. 운동·카페인·스트레스의 여러 표현을 인식하며 양쪽 평균·차이·기록 수와 계산 기준을 표시합니다. 조건별 최소 2일이 필요하고 미기록·샘플 수면은 개인 비교에서 제외합니다. 통계적 유의성이나 인과관계는 판정하지 않습니다.
- **계획:** 기상 날짜·시각과 6~10시간의 수면 목표로 기본 취침을 계산합니다. 직접 입력한 일정의 시작·종료와 준비 시간 30분이 수면 구간과 겹치면 취침 제안·부족 시간·대안 기상 시각을 갱신합니다.
- **요약·공유:** 날짜와 수면·체크인 항목을 개별 선택해 해당 내용만 PDF로 만듭니다. 미리보기 후 명시적으로 동의해야 공유 대상을 선택할 수 있습니다. 자동 전송하지 않으며 기록 변경 시 이전 PDF를 무효화합니다. 항목이 많으면 여러 페이지로 출력합니다.

수면 조회 결과는 메모리에 보관합니다. 체크인·목표·수동 일정은 UserDefaults에 저장합니다. 서버, 로그인, 클라우드 백업, 생성형 LLM과 외부 캘린더 동기화는 현재 구현하지 않았습니다. 이 앱은 기록 요약용이며 진단이나 치료 지시를 제공하지 않습니다.

## 구조

```text
JammanboApp → ContentView와 화면
  ├─ SleepStore → HealthKit 읽기 → SleepNormalizer → 전체 이력·상세
  ├─ CheckInStore → CheckInRepository → 입력·수정·삭제·수신 확인
  ├─ PlanStore → 목표 계산과 수동 일정 저장
  ├─ AskView → AnalysisService → ReportSummary
  └─ SummaryView → ReportSummary → ReportExportStore → PDF 생성·미리보기·공유

JammanboWatchApp → WatchHomeView → WatchSessionStore
  └─ 영속 대기열 → WatchConnectivity → iPhone 저장 → 확인 응답 후 제거
```

[애플리케이션 구조](docs/architecture/Application_Structure.md)에 DFD, 모듈 구조도, 자료 사전, Mini-Spec과 FR-01~12 코드 추적표를 정리했습니다. SSAD 보완 문서의 내용을 최신 구현과 대조해 제출용 SSAD에 통합했습니다.

2026-11-08 P03·P05의 [피드백 수정과 검증](docs/qa/Feedback_P03_P05_2026-11-08.md)을 반영했습니다. 01 SSRD·02 UI/UX·03 SSAD의 원본과 제출 PDF를 v1.4로 재생성했습니다. [문서 개정 내역과 재생성 방법](docs/submission/Submission_Document_Update_2026-11-08.md)을 참고하세요. 기존 60초 영상은 11월 7일 화면이므로 운동·일정 조정·선택 공유 장면 갱신이 필요합니다.

## 문서와 제출물

| 구분 | 편집 원본 | 제출 또는 공유 파일 |
|---|---|---|
| SSRD 요구사항 | [01_Jammanbo_SSRD.docx](01_Jammanbo_SSRD.docx), [요구사항 텍스트](docs/requirements/SSRD.md) | [SSRD PDF](output/pdf/01_Jammanbo_SSRD.pdf) |
| UI/UX 기획안 | [02_Jammanbo_UIUX.pptx](02_Jammanbo_UIUX.pptx), 동일 내용의 [v6 원본](output/pptx/02_Jammanbo_UIUX_v6.pptx) | [UI/UX PDF](output/pdf/02_Jammanbo_UIUX.pdf) |
| SSAD 구조 명세 | [03_Jammanbo_SSAD.docx](03_Jammanbo_SSAD.docx), [GitHub 열람용 구조 문서](docs/architecture/Application_Structure.md) | [SSAD PDF](output/pdf/03_Jammanbo_SSAD.pdf) |
| 고객 검증 계획과 빈 기록 양식 | [05_Jammanbo_Customer_Validation.docx](05_Jammanbo_Customer_Validation.docx) | [테스트 패킷](docs/user-test/Customer_Test_Packet.md) |
| 시연 영상 | [1분 대본과 촬영 절차](docs/submission/One_Minute_Demo_Script.md) | 기존 60초 영상 있음 · 피드백 반영 화면 재촬영 및 YouTube 링크 기록 필요 |
| 코드 검토 | [SSAD 반영 내역과 검증 상태](docs/qa/SSAD_Alignment_Review.md) | [다른 AI 에이전트용 검토 안내](docs/qa/AI_Review_Guide.md) |

SSRD는 무엇을 만들고 검수할지, UI/UX 기획안은 화면과 사용자 흐름을, SSAD는 데이터·모듈·외부 시스템의 관계와 내부 규칙을 설명합니다. 과제에 언급된 MBOX 원본은 저장소에서 확인되지 않아 `9주차/`의 UI/UX·MBASE 예시를 참고합니다. MBOX의 약어 풀이는 확정하지 않았습니다.

제공받은 `Jammanbo_SSAD_Application_Structure.docx`는 참고 원본으로 보존했습니다. 최신 구조는 통합 SSAD와 Markdown을 기준으로 확인합니다. `output/pptx/02_Jammanbo_UIUX_v4.pptx`·`output/pptx/02_Jammanbo_UIUX_v5.pptx`와 `docs/archive/slides_v1.ndjson`, `04_Jammanbo_Prototype.html`은 이전 기획 참고본입니다. `9주차/`는 수업 참고자료로 Git에서 제외합니다.

## 실행과 검증

macOS와 Xcode 27 이상에서 프로젝트를 엽니다. 최소 대상은 iOS 17, watchOS 10입니다.

```sh
open Jammanbo.xcodeproj
```

`Jammanbo` 스킴에서 iPhone을 선택하고 Signing & Capabilities의 Team을 설정해 실행합니다. 프로젝트에는 Watch 앱도 임베드되어 있어 해당 타깃의 서명도 확인해야 합니다. 이미 구성된 프로젝트는 XcodeGen을 다시 실행할 필요가 없습니다. `project.yml`을 수정해 재생성할 때는 XcodeGen 2.46 이상을 사용하고 기기 서명 Team을 다시 확인합니다.

UI에 의존하지 않는 계산·저장 검사:

```sh
sh scripts/check_domain_logic.sh
```

서명 없는 iPhone·Watch 빌드 확인:

```sh
xcodebuild -project Jammanbo.xcodeproj -scheme Jammanbo \
  -destination 'generic/platform=iOS' -derivedDataPath /tmp/JammanboDerivedData \
  CODE_SIGNING_ALLOWED=NO build
```

이 명령은 설치용 서명을 만들지 않습니다. 실제 HealthKit, Watch 전달과 공유 동작은 기기에서 확인해야 합니다. Windows에서는 GitHub 소스를 읽고 리뷰할 수 있지만 Xcode 빌드와 iOS 시뮬레이터 실행은 할 수 없습니다.

## 진행 상태와 남은 일

- 요구사항·화면·아키텍처 문서와 테스트·시연 양식을 정리했습니다.
- 사용자가 본인 iPhone에서 앱 실행을 확인했습니다. HealthKit의 실제 결과와 Watch 전달을 모두 검증한 상태로 간주하지 않습니다.
- 자막·오디오 없는 60초 시연 영상을 제작했습니다. [촬영·검수 기록](docs/submission/Video_Recording.md)을 참고하세요.
- 실제 참여자의 과업 결과와 분석 보고서, YouTube 업로드 링크는 아직 없습니다.
- 수면 정규화·저장·전송 큐·PDF 무효화 등 자동 검사 105개와 iPhone·Watch 기기용·시뮬레이터용 빌드가 통과했습니다. 별도 Mac Catalyst 검증 앱에서 이력·수정·재실행·질문·PDF 흐름도 확인했습니다.
- 구현 내역과 실기기 검증 목록은 [기능 구현 보고서](docs/qa/Functional_Implementation_2026-11-07.md)를 참고합니다. 실제 HealthKit·Watch 전달·iPhone 소프트웨어 키보드는 기기 확인이 남아 있습니다.

실제 참여자의 동의와 사용 관찰을 수집하고, AI 코드 리뷰 결과는 보조 검토로 구분합니다. 식별 가능한 건강 기록과 원자료를 저장소에 올리지 않으며 공개 영상에는 샘플 데이터를 사용합니다.
