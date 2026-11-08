# 01~03 제출 문서 v1.4 개정 내역

2026-11-08 · P03·P05 피드백을 현재 앱 구현과 제출 자료에 연결했다. 기존 원본 파일명을 유지하고 제출 PDF를 교체했다. UI/UX의 동일 내용 버전 사본은 v6이며 v4·v5는 이전 참고본으로 보존한다.

| 자료 | 편집 원본·텍스트 | 제출 PDF | 분량 |
|---|---|---|---|
| 01 SSRD | [DOCX](../../01_Jammanbo_SSRD.docx) · [Markdown](../requirements/SSRD.md) | [PDF](../../output/pdf/01_Jammanbo_SSRD.pdf) | 5쪽 |
| 02 UI/UX | [PPTX](../../02_Jammanbo_UIUX.pptx) · [v6 사본](../../output/pptx/02_Jammanbo_UIUX_v6.pptx) | [PDF](../../output/pdf/02_Jammanbo_UIUX.pdf) | 13슬라이드 |
| 03 SSAD | [DOCX](../../03_Jammanbo_SSAD.docx) · [Markdown](../architecture/Application_Structure.md) | [PDF](../../output/pdf/03_Jammanbo_SSAD.pdf) | 12쪽 |

## 반영 내용

| 피드백 | SSRD | UI/UX | SSAD |
|---|---|---|---|
| P03 운동 입력·질문 표현 | FR-03·05·07: 있음·없음·미기록, 구형 기록 nil 보존, 운동·산책·러닝·workout 표현 인식, 복합 질문 안내 | 4·6·7·8번: 운동 입력·Watch·질문 예시·비교 기준 | P2·P4, F3·F4, CheckIn·Message, MS02·03 |
| P03 비교 근거 | FR-06·07: 두 평균·차이·일수·날짜·출처, 각 2일 계산 최소치, 미기록·샘플 제외. 통계적 유의성·인과·임상 효과 아님 | 8·11·12번: 기준·자료 부족·근거 이해 재시험 | 최신 체크인·같은 기상일 결합, 결과·근거·해석 한계 |
| P05 일정 미반영 | FR-08~10: 시작·종료, 자정·준비 30분, 확보·부족 시간·대안 기상, 목표 자체 유지 | 9·11·12번: 22:00~00:00 → 00:30, 확보 6h30·부족 1h30·대안 08:30, 삭제·예외 | PlanEvent.endTime, PlanRecommendation, MS04, 구형 종료+1시간 보완 |
| P05 공유 통제 | FR-11·12, NFR-04: 날짜·필드 선택→PDF 확인→최종 동의→대상 선택, 취소 재동의·오래된 문서 차단 | 10·11·12번: 기본 최소 항목, 미선택 제외, 동의 전 차단·변경·취소 | ExportReport 투영, F8·F9, 문서 ID·현재 스냅샷·동의 검사, MS05·06·다중 페이지 |

외부 캘린더 동기화·생성형 LLM·자동 의료진 전송은 현재 범위에 포함하지 않는다. 화면과 계산 사례의 값은 설명용 예시이며 고객 측정 결과가 아니다.

## 문서 검증

SSRD 5쪽·SSAD 12쪽을 DOCX에서 PDF·PNG로 렌더링해 전체 페이지의 한글·표·페이지 경계를 확인했다. SSRD의 NFR 표가 한 줄만 다음 페이지로 넘어가던 현상을 조정했다.

UI/UX는 기존 편집 가능한 덱을 불러와 기존 도형·위치·슬라이드 크기를 유지하고 문구를 수정했다. 12번 과업 표도 네이티브 표로 유지했다. 패키지 무결성·13슬라이드·크기·폰트·표 보존 검사와 재가져오기 검사를 통과했다. 13개 슬라이드와 최종 PDF 전체를 렌더링해 잘림·겹침을 확인했다. 루트 PPTX와 v6 사본은 바이트가 같다.

이는 문서 동기화·레이아웃 검증이다. 앱의 개발 검증은 [피드백 반영 보고서](../qa/Feedback_P03_P05_2026-11-08.md)에 있는 105개 자동 검사·서명 없는 빌드·시뮬레이터·실제 UIKit 생성기 결과를 인용한다. 이번 문서 작업에서 새 실기기·고객 테스트를 수행한 것으로 기록하지 않는다.

## 원본 재생성

Codex artifact runtime이 설치된 macOS에서 저장소 루트를 기준으로 실행한다. Markdown을 수정하면 01·03 원본에 반영된다. UI/UX 문구는 JavaScript의 updates와 과업 표 값을 수정한다.

```sh
"$HOME/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3.12" scripts/sync_submission_documents.py
sh scripts/sync_submission_deck.sh
sh scripts/render_submission_documents.sh
```

DOCX 생성은 01·03만 대상으로 하며 05 고객 양식을 덮어쓰지 않는다. 덱 생성은 보존된 v5를 기준으로 v6와 루트를 갱신한다. PDF 생성은 01·03 DOCX와 v6 덱을 사용한다. 각 명령이 출력한 임시 폴더의 모든 페이지·슬라이드를 확인한다. 도식 변경은 docs/architecture/assets/*.dot를 Graphviz로 PNG 재출력한 뒤 DOCX를 재생성한다. 별도 런타임은 JAMMANBO_ARTIFACT_RUNTIME으로 지정할 수 있다.

## 남은 제출 작업

P03·P05 개선 후 고객 재시험과 실제 HealthKit·Watch 운동 전달·기기 공유 확인이 남아 있다. 05 고객 검증 양식과 이미 수집한 원자료는 이번 01~03 개정 대상이 아니며 결과를 임의로 추가하지 않았다. 기존 60초 영상은 11월 7일 화면이므로 운동·일정 조정·선택과 동의 장면을 갱신해야 한다. 제공받은 SSAD 참고 원본도 그대로 보존했다.
