# 잠만보 소프트웨어 구조와 애플리케이션 설계

SSAD · 버전 v1.4 · 2026-11-08 · Team 17

잠만보는 HealthKit 수면과 iPhone·Apple Watch 체크인을 연결하는 네이티브 앱이다. 이 문서는 DFD, 모듈 구조, 자료 사전과 소단위 명세를 Swift 구현에 연결한다. P03의 운동·비교 근거와 P05의 일정 연계·선택 공유·최종 동의를 반영했다.

## 1 제품 범위와 시스템 경계

| 항목 | 현재 설계 |
|---|---|
| 실행 환경 | iOS 17 이상, watchOS 10 이상, SwiftUI |
| 앱 구성 | Jammanbo iPhone 앱 + JammanboWatch 동반 앱. 첫 검증은 iPhone 중심. |
| 외부 시스템 | HealthKit 읽기 전용, 사용자가 최종 선택한 시스템 공유 대상 |
| 내부 처리 | WatchConnectivity, 기기 내 규칙 계산, UserDefaults, 선택 데이터 PDF |
| 제외 범위 | 생성형 LLM, 외부 캘린더 동기화, 서버 계정·클라우드, 주간 일정 최적화 |
| 검증 경계 | 자동 검사 105개·서명 없는 빌드·iPhone 시뮬레이터 검증 완료. 개선 후 고객 재시험과 실제 Watch 전달은 미확인. |

iPhone과 Watch 앱을 함께 시스템 경계 안에 둔다. Watch 입력 주체는 Watch를 조작하는 사용자다. 상담자는 앱 계정이나 직접 연결 API가 없으며, 사용자가 PDF를 외부 공유한 경우에만 결과를 받는다. 건강 데이터의 자동 외부 전송 경로는 없다.

P03 비교는 같은 기상일의 관찰 평균이다. 계산 최소 표본과 근거를 노출하지만 통계적 유의성이나 임상적 효과를 판단하지 않는다. P05 일정은 사용자가 입력한 해당 밤의 일정만 반영하며, 공유는 사용자 선택·미리보기·동의를 모두 거친다.

## 2 문맥 DFD

![사용자·HealthKit·선택 공유 대상과 잠만보의 문맥 흐름](assets/context.png)

| 흐름 | 자료 구성 | 경계 |
|---|---|---|
| 사용자 입력 | 질문, 운동 포함 체크인, 기상 날짜·목표, 시작·종료 일정, 공유 선택·동의 | 사용자 → 앱 |
| 사용자 결과 | 수면·출처, 비교 근거, 일정 반영 취침·부족 시간, 선택 PDF 미리보기 | 앱 → 사용자 |
| 수면 조회 | 읽기 요청, HKCategorySample 목록 | 앱 ↔ HealthKit |
| 선택적 공유 | 선택된 날짜·필드만 담은 PDF | 앱 → 사용자가 고른 외부 대상 |

공유 데이터 선택과 최종 동의는 서로 다른 단계다. 동의는 파일을 자동 발송하는 명령이 아니라, 현재 미리보기 문서에 대해 시스템 공유 시트를 열도록 허용한다. 실제 앱·수신자·전송 여부는 사용자가 시스템 시트에서 결정한다.

## 3 Level 1 DFD

![여섯 프로세스와 내부 저장소의 데이터 흐름](assets/level1.png)

| 프로세스 | 책임 | 주요 자료 |
|---|---|---|
| P1 수면 수집·정규화 | 출처 겹침 제거, 기상일 집계 | F1 샘플 → F2 SleepNight |
| P2 체크인 관리 | 운동 미기록 보존, 폰 입력·Watch 검증·UUID 중복 제거 | F3 폰 입력, F4 Watch payload·확인 |
| P3 대시보드 조회 | 최근 수면·단계·출처·목표 대비 비율 | D1 수면, D3 목표 |
| P4 기록 질문·비교 | 표현 정규화, 평균·단계·습관 비교, 기준·근거 | F5 질문 → F6 답변 |
| P5 목표·일정 관리 | 시작·종료 일정과 준비 30분을 반영한 취침 제안 | F7 목표·일정 → PlanRecommendation |
| P6 선택 PDF·동의 | 선택 자료 투영, 다중 페이지, 문서 유효성·최종 동의 | F8 선택 자료, F9 공유 승인 |

화살표는 자료 이동이며 실행 순서나 함수 호출이 아니다. D1은 메모리 수면 상태다. D2는 최근 30개 체크인과 별도 수신 UUID 이력, D3은 목표·일정, D4는 폰 저장 확인까지 유지하는 Watch 대기열이다. PDF 선택·동의는 영속 체크인 저장소와 분리된 일시 상태다.

## 4 애플리케이션 모듈 구조

![iPhone·Watch의 화면·서비스·저장소 의존 관계](assets/structure.png)

JammanboApp이 SleepStore·CheckInStore·PlanStore를 생성·주입한다. 화면은 표시·입력, 서비스는 계산·검증, 저장소는 보관을 담당한다. ReportSummary는 최근 7일 범위를 통일한다. PDF 생성에는 원본 대신 선택 필드만 담은 ExportReport를 넘긴다.

| 모듈 | 역할 | 접근 경계 |
|---|---|---|
| SleepStore / SleepNormalizer | 권한·조회·겹침 제거·기상일 집계 | HKHealthStore / Foundation |
| CheckInStore / Repository | 입력·편집·운동 nil 보존·중복 제거 | WCSession / UserDefaults |
| WatchSessionStore / CheckInOutbox | 확인 전 보관·재시도 | Watch UserDefaults / WCSession |
| CheckInMessage / DeliveryRetryState | 공통 payload·확인·재시도 상태 | 두 타깃의 Shared 코드 |
| AnalysisService / AskView | 표현 분류·계산·기준·근거 표시 | ReportSummary 읽기 |
| PlanStore / PlanView | 목표·종료 일정·충돌 제안 | 주입 가능한 UserDefaults |
| ReportSummary / ReportExportOptions | 범위 집계·공유 날짜와 필드 선택 | Foundation 값 타입 |
| ReportExportFlow / ReportExportStore | 미리보기·동의·문서 유효성 검사 | 일시 상태·PDFKit·시스템 시트 |
| ExportReport / ReportPDFGenerator | 선택 자료만 다중 페이지 PDF로 렌더링 | UIKit / 앱 임시 파일 |

Watch와 폰 사이에는 직접 함수 호출이 없다. WatchConnectivity 비동기 자료·확인 응답만 오간다.

## 5 DFD·코드·요구사항 추적

| DFD | 구현 파일 | SSRD | 검증 과업 |
|---|---|---|---|
| P1·P3 | Health/SleepStore.swift, SleepNormalizer.swift, SleepHistoryView.swift | FR-01·02·04 | T1 수면·출처 |
| P2 | CheckIn/CheckInStore.swift, CheckInRepository.swift, CheckInHistoryView.swift; WatchSessionStore.swift | FR-03·04 | T2a 폰·T2b Watch |
| P4 | Analysis/AnalysisService.swift, AskView.swift, Reporting/ReportSummary.swift | FR-05·06·07 | T3 운동·근거 |
| P5 | Planning/PlanStore.swift, PlanView.swift | FR-08·09·10 | T4 자정 일정 |
| P6 | Reporting/PDFPreviewSheet.swift, ReportExportStore.swift, ReportSummary.swift; ReportPDFGenerator.swift | FR-11·12, NFR-04 | T5 선택·동의 PDF |

iPhone 파일 경로는 Jammanbo 기준이며 WatchSessionStore는 JammanboWatch/Connectivity에 있다. 공통 전송 모델은 Shared 폴더에 있다. 고객 과업 ID는 UI/UX 기획안과 공유한다.

P03는 운동 입력→동의어 질문→같은 날짜 결합→계산 근거 표시까지 P2·P4를 연결한다. P05 일정은 저장만으로 끝나지 않고 P5의 재계산 결과가 화면에 나타나야 한다. P05 공유는 P6에서 선택 자료와 승인된 현재 문서만 외부로 나가는 경계를 만든다.

## 6 자료 흐름 사전

| ID | 자료 구성 | 발신·수신 |
|---|---|---|
| F1 | HKCategorySample startDate·endDate·value | HealthKit → SleepStore |
| F2 | SleepNight 목록, sourceLabel, message | SleepStore → 화면·ReportSummary |
| F3 | mood, stress, caffeine, exercise Bool? | CheckInView → CheckInStore |
| F4 | id, timestamp, mood, stress, caffeine, 선택 exercise | WatchSessionStore → WCSession → CheckInStore |
| F4 확인 | kind=checkInReceipt, id | 폰 저장·중복 확인 → Watch 대기열 |
| F5 | question String | AskView → AnalysisService |
| F6 | AnswerCard text·evidence | AnalysisService → AskView |
| F7 | wakeMinutes, sleepGoalMinutes, PlanEvent 목록; 화면의 wakeDate | PlanView ↔ PlanStore |
| F8 | 선택 날짜·필드 ReportExportOptions → 선택값만 담은 ExportReport | ReportSummary.export → ReportPDFGenerator |
| F9 | 최종 동의, 문서 UUID, 현재 ReportContent 스냅샷 | ReportExportFlow → authorizeSharing → 시스템 공유 시트 |

F8의 투영은 단순 화면 숨김이 아니다. 제외한 원본 값은 PDF 생성기의 입력에 들어가지 않는다. F9 검사는 미리보기와 실제 공유 대상 파일이 현재 선택·기록에 대응하는지 확인한다. 동의가 없거나 문서·기록이 바뀌었으면 공유 URL을 허용하지 않는다.

운동은 전송·보관 과정에서 true·false·nil을 구분한다. 구형 JSON·payload에 운동 키가 없으면 nil로 처리해 ‘운동하지 않음’으로 오분류하지 않는다.

## 7 자료 사전

| 자료 | 필드 | 의미·제약 |
|---|---|---|
| SleepNight | id·date, 선택 startDate·endDate, 총·단계 분, 단계 제공 Bool, isSample | 기상일 합산. 미제공과 0분 구분. 샘플 표시 보존. |
| CheckIn | id UUID, date, mood, stress, caffeine Bool, exercise Bool?, source | 운동 미기록 nil. 폰·Watch 출처와 원래 시각 보존. |
| CheckInMessage | id UUID, timestamp Double, mood, stress, caffeine, exercise Bool? | UUID 문자열 payload, 구형 운동 누락 nil. |
| PlanEvent | id UUID, title, time Date, endTime Date | 비어 있는 제목 거부. 구형 종료는 시작+1시간으로 보완·안내. |
| 목표·화면 날짜 | wakeMinutes, sleepGoalMinutes; wakeDate | 저장 기본 420·480분. 화면 기상일 기본 내일, 목표 360~600분. |
| PlanRecommendation | 기본·제안 취침, 기상, 충돌 목록, 확보·부족 분, 목표 유지 대안 기상 | 여러 충돌의 최종 종료+30분. 확보 분은 0 미만 불가. |
| AnswerCard | text, evidence | 결과·평균·차이·일수·날짜·출처와 계산 한계. 영속 저장 없음. |
| ReportSummary | nights, checkIns, source, periodStart, generatedAt | 오늘 포함 최근 7개 달력 날짜. 기록 없는 날을 0분 평균에 넣지 않음. |
| ReportExportOptions | 날짜, 총 수면·평균, 단계, checkInFields | 기본 총 수면·평균만, 나머지 제외. 무선택 생성 차단. |
| ExportReport | 선택 labels, source, sleepRows, checkInRows, 선택 average, includesCheckIns | 미선택 날짜·필드 제외. 체크인 미선택 시 개수도 제외, 시각은 날짜까지만. |
| ReportDocument | UUID, options, ExportReport, 생성 스냅샷, URL | 현재 기록·선택과 일치하는 미리보기만 승인. 원본 스냅샷은 유효성 비교용 메모리 상태. |

PlanRecommendation의 설명용 필드 이름은 구현 역할을 요약한 것이다. 실제 Swift 선언의 기준은 PlanStore.swift와 ReportExportStore.swift다.

## 8 저장소와 호환 규칙

| 저장소 | 키·위치 | 보관·호환 규칙 |
|---|---|---|
| D1 수면 | SleepStore.nights 메모리 | 실제·샘플 조회로 갱신. UserDefaults에 건강 원본 저장 안 함. |
| D2 체크인 | jammanbo.checkins.v1 | JSON, 시각 내림차순 최근 30건. 수정·삭제 저장. 구형 운동 누락 nil. |
| D2 수신 이력 | jammanbo.checkinReceipts.v1 | UUID 최대 1,000개. 재전송으로 수정·삭제가 되돌아가지 않도록 함. |
| 건강 연결 의사 | jammanbo.health.connectionRequested.v1 | 연결 요청 사실만 저장. 읽기 권한 허용을 단정하지 않음. |
| D3 목표 | jammanbo.targetWakeMinutes / jammanbo.targetSleepMinutes | 기존 정수 분 키 유지. 화면의 기상 날짜는 일시 선택. |
| D3 일정 | jammanbo.planEvents.v1 | 시작·종료 JSON. 종료 없는 구형 항목은 1시간 보완, 추가·삭제 저장. |
| D4 Watch 큐 | jammanbo.watch.pendingCheckIn.v1 | 최대 30건, 폰 확인 후 제거. 가득 차면 신규 저장 거부·안내. |
| PDF | 앱 임시 디렉터리의 UUID 파일 | 생성 시 자체 파일 중 24시간 지난 것 정리. 선택값만 렌더링. |
| 선택·동의 | ReportExportFlow·Store 메모리 | 초기 미동의, 기록·선택·문서 변경 시 무효화. 시트 개방 즉시 동의 초기화. 영구 동의 저장 없음. |

UserDefaults는 전용 암호화 건강 저장소가 아니다. 상용 배포 전 보관·보호·삭제 정책을 검토한다. 현재 서버·LLM 전송과 외부 의료진 직접 전송 API는 없다.

## 9 소단위 명세: 수면과 체크인

### MS01 수면 정규화

최근 14일 HealthKit sleepAnalysis 샘플의 구간 경계를 나누고 각 시간 구간에 하나의 기록만 선택한다. 상세 단계가 미분류보다, 그다음 Watch 출처가 우선한다. 같은 조건은 출처 식별자 순으로 결정하고 같은 출처 겹침은 awake가 우선한다. 잘못된 구간은 제외하고 미래 종료는 현재 시각까지 자른다.

인접 수면 간격이 90분 이내이거나 같은 inBed 구간이면 세션으로 묶는다. 세션의 마지막 수면 종료일을 로컬 기상일로 배정하고 같은 날의 세션·낮잠을 합산한다. 90분은 앱의 분류 정책이다. awake·inBed는 수면 합계에서 제외한다. 초로 누적한 뒤 분으로 표시하고 단계 합계와 총 시간을 일치시킨다.

총 시간 0인 날짜를 제외하고 오늘 포함 최근 7개 날짜만 표시한다. 조회 실패·빈 응답은 샘플·출처·안내를 함께 갱신하며 권한 거부라고 단정하지 않는다. 단계 미제공과 0분은 구분한다. 최초 권한 요청은 연결 버튼에서, 이후 실행·복귀·새로고침·observer 변경 때 재조회한다.

### MS02 체크인·운동·Watch 전달

폰은 새 UUID·현재 시각으로 체크인을 저장한다. 운동은 있음·없음·미기록 중 선택하고 구형 데이터의 운동 누락을 nil로 읽는다. Watch도 같은 선택 값을 payload와 로컬 대기열에 보관한다. 생성 UUID를 유지하며 최대 30건까지 큐에 넣고, 가득 차면 신규 저장을 거부한다.

폰은 UUID·유효 시각·각 필드 타입을 검증하고 최근 30건을 시각순 저장한다. 수신 UUID 최대 1,000개로 중복 제거 후 확인 응답을 보낸다. 운동 키가 없으면 nil이며 false로 대체하지 않는다. 편집·삭제는 원래 시각·출처를 유지하고 운동 선택도 반영한다.

Watch는 폰 확인 후 해당 UUID만 제거한다. 오류 재시도는 5~300초, 운송 성공 후 확인이 없으면 60초 뒤 재시도한다. 운송 중 UUID는 중복 예약하지 않는다. 앱 복귀·연결 변경·수동 재시도·백그라운드 전달을 처리한다. 실제 Watch 운동 전달과 재연결은 페어링 기기에서 추가 검증한다.

## 10 소단위 명세: 질문과 일정

### MS03 표현 변형·비교 근거

AnalysisService는 대소문자·문자 폭·공백·문장부호를 정리하고 평균, 단계, 습관 질문을 분류한다. 운동·산책·러닝·달리기·조깅·헬스·요가·exercise·workout·running은 운동 여부 비교로, 커피·카페인은 카페인, 긴장·스트레스는 스트레스로 분류한다. 여러 습관이면 하나를 고르도록 안내한다. 운동 종류·강도별 비교나 임의 질문의 자유 추론은 하지 않는다.

평균은 존재하는 수면 날짜만, 단계는 해당 값이 제공된 최근 기록을 사용한다. 습관 비교는 샘플 수면을 제외하고 같은 기상 날짜의 최신 체크인 한 건을 결합한다. 운동 nil은 제외한다. 운동 있음/없음, 카페인 있음/없음, 높은 스트레스/나머지를 각 2일 이상 확보해야 두 평균과 차이를 계산한다.

조건별 평균·차이·일수·날짜·출처, 미기록 제외와 비교 기준을 보여준다. 2일은 계산 최소치이며 유의성 판단 기준이 아니다. 인과·임상 효과·‘의미 있는 변화’를 단정하지 않는다. 부족하면 그룹 일수·날짜와 기록 필요를 안내한다. AskView는 기록 내용 변경 시 답변을 갱신한다.

### MS04 기상 날짜·일정 종료·취침 제안

기상 날짜는 기본 내일이며 목표는 기본 07:00·480분이다. 수면 목표는 360~600분·15분 간격. 기본 취침은 선택 기상 날짜·시각에서 목표 분을 뺀다. 일정은 제목·시작·기간을 입력하고 종료를 표시한다. 구형 종료 누락은 시작+1시간으로 읽고 사용자에게 보완 사실을 알린다.

기상 전 시작하고 종료+30분이 기본 취침보다 늦은 일정을 충돌로 본다. 제안은 기본 취침과 충돌 일정의 최종 종료+30분 중 늦은 시각이다. 목표 자체를 변경하지 않고 확보 시간·부족 시간과 목표 유지 대안 기상을 표시한다. 기상 전 수면이 불가능하면 확보를 0으로 제한하고 조정을 안내한다.

다음 날 07:00·8시간, 22:00~00:00 일정 → 기본 23:00, 제안 00:30, 확보 6시간 30분, 부족 1시간 30분, 대안 기상 08:30. 충돌 삭제 시 기본 제안으로 복귀한다. 외부 캘린더나 주간 최적화는 없다.

## 11 소단위 명세: 선택 PDF와 최종 동의

### MS05 선택·투영·미리보기

SummaryView에서 ‘공유할 데이터 선택’으로 ReportExportFlow를 연다. 최근 7일 중 날짜, 총 수면·평균, 단계, 기분·스트레스·카페인·운동을 각각 선택한다. 기본은 총 수면·평균만, 단계·체크인은 제외한다. 무선택 생성은 막는다.

ReportSummary.export(options:)는 선택 날짜·필드만 담은 ExportReport를 생성한다. PDF 생성기에 원본 ReportSummary를 넘기지 않는다. 미선택 날짜·값은 출력 입력에서 제외하고 체크인 미선택 시 체크인 개수도 제외한다. 체크인 시각은 날짜까지만 표시한다. 선택 수면 기록만 평균하고 단계 미제공과 0분을 구분하며 출처·기간을 명시한다.

UIKit ReportPDFGenerator는 A4 595×842 포인트에 행과 페이지 공간을 계산해 필요한 만큼 새 페이지를 만든다. 선택 30건도 마지막 행까지 포함하며 ‘1페이지’ 고정 제약은 없다. 앱 임시 디렉터리에 UUID 이름으로 원자 저장하고 PDFKit에서 ‘선택한 PDF 확인’을 제공한다.

### MS06 최종 동의·현재 문서 승인

미리보기의 최종 동의는 처음에 체크되지 않는다. ‘동의하고 공유 대상 선택’은 사용자가 동의한 뒤에만 활성화한다. ReportExportStore.authorizeSharing는 명시적 동의, 미리보기 문서 UUID, 현재 ReportContent 스냅샷을 검사한다. 선택 변경은 문서를 재준비하고 기록 변경은 synchronize로 무효화한다. 오래된 PDF URL은 승인하지 않는다.

공유 시트 개방 즉시 동의를 초기화한다. 취소 후 재시도도 새 동의가 필요하다. 실제 수신자·앱·전송 여부는 사용자가 시스템 시트에서 선택한다. 자동 전송·ShareLink 우회·의료진 직접 전송 API는 없다. 사용자 기록과 목표는 공유 취소로 바뀌지 않는다.

동의는 현재 선택 문서에만 적용된다. 최종 확인 이전 단계에서 앱 서버나 외부 서비스로 자료를 전송하지 않는다. 진단서나 치료 지시로 표현하지 않는다.

## 12 피드백 추적·검증 결과·남은 확인

| 피드백 | 반영 설계 | 연결·재시험 |
|---|---|---|
| P03 근거 신뢰·질문 표현·운동 없음 | 선택 운동과 nil 호환, 동의어 분류, 각 2일·최신 결합, 기준·평균·차이·일수·날짜·출처 | MS02·03, FR-03·05·06·07, T2·T3 |
| P05 일정과 취침 분리 | 종료 시각·자정·준비 30분·복수 충돌·부족 시간·대안 기상 | MS04, FR-08~10, T4 |
| P05 선택·최종 동의 필요 | 선택 투영·다중 페이지·문서 유효성 검사·매 시도 동의·취소 초기화 | MS05·06, FR-11·12·NFR-04, T5 |

| 확인 항목 | 2026-11-08 결과 |
|---|---|
| 도메인 회귀 검사 | 105개 통과. 구형 운동 nil, 표현 변형, 자료 부족, 자정·여러 일정, 선택 투영·동의·오래된 문서 차단 포함. |
| 빌드 | iPhone·임베드 Watch 기기용 서명 없는 빌드와 시뮬레이터용 빌드 성공. 설치·서명·실기기 전달 검증과 구분. |
| iPhone 시뮬레이터 | 운동 입력·P03 문구·workout 인식, 기준 안내, 합성 자정 일정의 00:30·6시간 30분·08:30, 선택 운동만 PDF, 동의 전 차단·시트 취소·재동의 확인. |
| 실제 UIKit PDF 생성기 | 합성 30건으로 최소 선택 1페이지·운동만 2페이지·전체 3페이지. 제외값 부재·마지막 행 포함, 전체 6페이지 한글·경계 시각 확인. |
| 남은 실제 검증 | 실제 HealthKit 기록·단계, Watch 운동 전달·오프라인 재연결, 실제 기기 공유, P03·P05 개선 후 과업 재시험. |

자동 검사와 합성 데이터 검증은 고객 재시험 결과가 아니다. 실제 참여자의 성공·시간·도움·의견을 별도 수집하며 결과를 추정해 채우지 않는다. 세부 개발 검증 기록은 docs/qa/Feedback_P03_P05_2026-11-08.md에 있다.

제공받은 Jammanbo_SSAD_Application_Structure.docx는 참고 원본으로 보존한다. 최신 제출 설계는 이 문서와 03_Jammanbo_SSAD.docx v1.4다.
