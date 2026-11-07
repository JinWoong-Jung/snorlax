# SSAD 반영 내역과 검증 상태

> 이 문서는 후속 수정 전 기록입니다. 최신 구현과 검증은 [기능 구현 보고서](Functional_Implementation_2026-11-07.md)를 확인하세요.

검토일 2026-11-07. 제공받은 `Jammanbo_SSAD_Application_Structure.docx`를 현재 저장소의 Swift 코드와 대조했다. 해당 파일은 참고 원본으로 보존하고, 검토 결과를 `03_Jammanbo_SSAD.docx`, 제출 PDF와 `docs/architecture/Application_Structure.md`에 통합했다.

## 반영한 차이

| 항목 | 참고 문서의 설명 또는 기존 상태 | 반영 결과 |
|---|---|---|
| 시스템 경계 | iPhone·Watch 전체 제품과 Watch 외부 개체의 경계가 혼재 | 두 앱을 시스템 내부로 정의. Watch를 조작하는 사용자를 외부 입력 주체로 표시. |
| 구조 추적 | DFD와 모듈을 연결하나 분석·계획 책임이 View 내부에 있음 | P1~P6, 코드, FR-01~12, 테스트 과업을 연결. AnalysisService와 PlanStore 분리. |
| 수면 단계 | 총 시간 3단계 합산, unspecified를 core로 합침 | 실제 최신 모델의 unclassifiedMinutes와 단계 제공 플래그 반영. 미제공과 0분 구분. |
| 기간 | 최근 14일 조회와 화면 최대 7건을 혼동할 수 있음 | 14일 조회 후 최근 7개 달력 날짜 표시. 질문·요약·PDF는 ReportSummary로 같은 기간 사용. |
| 오류 복구 | 읽기 오류 문구와 기존 실제 기록이 함께 남을 수 있음 | 오류·미제공 상태에서 샘플 목록과 출처·안내를 함께 갱신. 권한 거부를 빈 응답만으로 단정하지 않음. |
| Watch payload | UUID와 대기열 목록, 구형 호환 설명 누락 | 기존 코드의 ID 중복 제거, 최대 30건 대기, 구형 payload 읽기와 전송 예약 상태 명세화. |
| 생활습관 비교 | 같은 날짜 결합과 한쪽 그룹 없음만 기술 | 하루 최신 체크인, 조건별 최소 2일, 근거 날짜·출처·그룹 수 반영. 샘플 수면과 개인 체크인은 비교에서 제외. |
| 차이 없음 | 0분 차이도 길었다고 표현할 수 있음 | 평균이 같으면 차이가 없었다고 표시. |
| 계획 | PlanView가 계산과 저장을 모두 담당 | PlanStore로 이동. 기존 저장 키·기본값 유지. 일정은 취침 계산에 자동 반영되지 않음을 명시. |
| 목표 달성률 | 홈에서 8시간 기준 고정 비율 | 사용자가 정한 수면 목표를 사용하도록 연결. |
| PDF | 고정 파일명·기간·단계 설명이 최신 코드와 다름 | UUID 파일명, 동일 7일 체크인 범위, 실제 단계 표시와 줄바꿈 반영. |
| 제출 자료 | 루트 UI/UX와 고객 DOCX에 웹·LLM·주간 최적화 설명 잔존 | 현재 네이티브 범위로 통일. UI/UX 루트와 v5 동기화. 이전 NDJSON은 docs/archive로 이동. |
| 검증 과업 | Watch 연결이 전체 테스트·촬영의 선행 조건 | iPhone 과업 T2a와 선택 Watch 과업 T2b를 구분. AI 검토와 실제 고객 결과도 구분. |

## 실행한 검증

- `sh scripts/check_domain_logic.sh`: 19개 검사 통과.
- 서명 없는 generic iOS 빌드: **BUILD SUCCEEDED**. Jammanbo와 임베드된 JammanboWatch를 함께 컴파일했다.
- 첫 빌드는 실행 환경의 sandbox-exec 제한으로 SwiftUI 매크로 프로세스가 차단됐다. 동일한 서명 없는 빌드를 제한 밖에서 다시 실행해 성공했다.
- 새 Swift 파일이 Xcode 프로젝트와 XcodeGen 소스 범위에 포함되는지 확인했다. 기존 DEVELOPMENT_TEAM 설정과 UserDefaults 키는 유지했다.
- DOCX·PPTX와 제출 PDF를 동기화했다. SSRD 4페이지, SSAD 9페이지, 고객 검증 양식 6페이지, UI/UX 13슬라이드 전체를 렌더링해 한글·표·구조도·여백을 검토했다. 최종 수정 후 변경 페이지를 재검토하고 나머지 페이지는 이미지가 동일함을 확인했다.
- Office 압축 파일 무결성, Markdown 파일 링크, 문서 생성 스크립트 문법과 git diff 공백 검사를 통과했다. 루트 UI/UX와 v5 원본이 동일한지도 확인했다.

계산 검사는 날짜 범위와 미래·오래된 기록 제외, 결측 날짜의 평균, 빈 질문·미지원 질문, 단계 미제공, 샘플 비교 제외, 하루 최신 체크인, 조건별 최소 2일, 동일 평균, 선택 목표 달성률, 목표 취침의 자정 경계, 일정 공백 거부·저장·삭제·재실행 복원을 포함한다.

빌드에는 AppIntents 의존성이 없어 메타데이터 추출을 생략한다는 안내와 iPad 인터페이스 방향 경고가 남는다. 현재 unsigned 빌드 성공은 App Store 검수·배포 서명 또는 실제 기기 설치 성공을 의미하지 않는다.

## 실제 기기에서 남은 확인

1. HealthKit 권한 요청, 읽을 수 있는 기록 없음, 조회 오류와 상세 단계가 없는 기록.
2. 여러 수면 앱의 겹치는 HealthKit 샘플과 출처 우선순위. 현재 구간 중복 병합은 구현하지 않았다.
3. Watch 설치·페어링·비연결 후 전달·재연결·동일 UUID 수신. 전송 예약은 도착 완료가 아니다.
4. iPhone에서 체크인·목표·일정의 실제 재실행 복원과 키보드 완료 동작.
5. 실제 기기 PDF의 내용·레이아웃·공유 취소와 임시 파일 정리 정책.
6. 실제 사용자 과업, 접근성, 응답시간 측정과 익명화 피드백 수집.

사용자가 iPhone 앱을 실행했다고 보고한 근거는 있으나, 이번 작업에서는 사용자의 실제 기기에 새 버전을 설치하거나 HealthKit·Watch 전송을 실행하지 않았다. 실제 고객 테스트 결과와 공개 영상·YouTube 링크는 아직 없다.

## 문서 재생성

`docs/architecture/Application_Structure.md`와 테스트 패킷을 수정한 뒤 Codex artifact runtime의 Python으로 `scripts/sync_submission_documents.py`를 실행한다. 이 명령은 통합 SSAD·고객 DOCX, SSRD 텍스트 사본과 UI/UX의 관련 문구를 동기화한다. 도식 원본은 `docs/architecture/assets/*.dot`이며 Graphviz로 PNG를 만든다.

`sh scripts/render_submission_documents.sh`는 bundled LibreOffice와 문서 렌더러로 PDF와 검토용 페이지 이미지를 만든다. 별도 런타임 경로는 `JAMMANBO_ARTIFACT_RUNTIME`으로 지정한다. 명령 종료 후 출력되는 임시 폴더의 모든 페이지를 확인한다. 참고 SSAD 원본, 이전 v4 PPTX와 과거 웹 기획 자료는 자동 갱신 대상이 아니다.
