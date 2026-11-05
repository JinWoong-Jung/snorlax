# 잠만보 (Jammanbo)

Apple Watch 사용자의 수면 기록과 생활습관 기록을 연결하는 iPhone·Apple Watch 동반 앱 프로토타입입니다. 사용자가 수면 데이터와 아침 체크인을 함께 살펴보고, 개인 기록을 바탕으로 수면 목표를 세우며, 최근 기록을 상담용 PDF로 공유할 수 있도록 설계했습니다.

## 프로젝트 요약

- **iPhone 앱:** HealthKit 수면 기록과 최근 7일 추세, 아침 체크인, 기록 기반 질문과 근거, 수면 목표·수동 일정, 1페이지 요약 PDF를 제공합니다.
- **Apple Watch 앱:** 기분·스트레스·오후 카페인을 빠르게 입력하고 WatchConnectivity를 통해 iPhone에 전달합니다.
- **데이터:** 수면·체크인·목표·일정은 기기 안에 저장합니다. HealthKit 권한을 거부했거나 기록이 없을 때는 예시 데이터로 화면 흐름을 확인할 수 있습니다.
- **현재 범위:** 실제 생성형 LLM, 계정·서버, 클라우드 저장, 캘린더 계정 동기화는 구현하지 않았습니다. 질문 답변은 기기 내 규칙으로 만들며, 의료 진단이나 치료 지시를 제공하지 않습니다.

## 주요 기능

1. HealthKit에서 수면 분석 기록을 읽고 최근 7일 수면 시간을 보여줍니다.
2. iPhone 또는 Apple Watch에서 아침 기분·스트레스·카페인을 기록합니다.
3. 개인 기록에 관한 질문에 규칙 기반으로 답하고, 사용한 기간과 데이터 출처를 표시합니다. 기록이 부족하면 추정하지 않고 안내합니다.
4. 목표 기상 시각과 수면 시간을 기준으로 취침 목표를 계산합니다. 일정은 현재 직접 입력합니다.
5. 최근 기록 요약을 1페이지 PDF로 만들어 사용자가 직접 공유할 수 있습니다.

## 앱 구조

```text
iPhone (SwiftUI)
  ├─ HealthKit: 수면 분석 데이터 읽기
  ├─ 체크인·수면 목표·수동 일정의 로컬 저장
  ├─ 기록 기반 규칙형 질문과 근거 표시
  └─ 요약 PDF 생성 및 시스템 공유

Apple Watch (SwiftUI)
  └─ 기분·스트레스·카페인 체크인
       └─ WatchConnectivity transferUserInfo → iPhone
```

## 문서와 제출 파일

| 문서 | 설명 | 현재 파일 |
|---|---|---|
| **SSRD** | System/Software Requirements Definition. 제품 범위, 사용자와 시스템 요구사항, 품질 조건, 예외 상황, 검수 기준을 정의합니다. 무엇을 만들어야 하는지에 대한 기준 문서입니다. | 제출 PDF: `output/pdf/01_Jammanbo_SSRD.pdf`; 동기화한 편집 원본: `01_Jammanbo_SSRD.docx`. |
| **MBOX 참고 UI/UX 기획안** | 과제는 MBOX 파일을 참고하도록 안내합니다. 이 저장소와 `9주차/` 자료 폴더에서는 MBOX라는 이름의 원본 파일을 찾지 못했습니다. 대신 제출 UI/UX 문서에는 서비스 개요, 데이터 출처, 사용자 흐름, 화면별 설명, 빈 상태·오류, 고객 테스트 과업을 정리했습니다. MBOX는 여기서 과제에 지정된 UI/UX 참고 자료를 가리키는 이름으로 사용하며, 약어의 풀이는 확인되지 않았습니다. | 제출 PDF: `output/pdf/02_Jammanbo_UIUX.pdf`; 최신 편집 원본: `output/pptx/02_Jammanbo_UIUX_v4.pptx`. `02_Jammanbo_UIUX.pptx`는 이전 편집본입니다. |
| **SSAD** | System/Software Architecture Description. iPhone·Watch 앱, HealthKit, WatchConnectivity, 로컬 저장, PDF 내보내기 사이의 구성과 데이터 흐름, 권한·보안 결정을 설명합니다. 어떻게 만들었는지와 현재 구현 범위를 보여주는 문서입니다. | 제출 PDF: `output/pdf/03_Jammanbo_SSAD.pdf`; 동기화한 편집 원본: `03_Jammanbo_SSAD.docx`. |

`9주차/` 폴더에는 SSRD·UI/UX·프로토타입의 참고 예시가 있습니다. 이 폴더는 제출 결과물이 아니며 GitHub에 포함하지 않도록 `.gitignore`에서 제외합니다.

## 저장소 구성

```text
snorlax/                            # 저장소 루트
  Jammanbo/                         # iPhone 앱 소스
  JammanboWatch/                    # Apple Watch 동반 앱 소스
  Jammanbo.xcodeproj/               # Xcode 프로젝트
  project.yml                       # XcodeGen 프로젝트 정의
  output/
    pdf/                            # SSRD, UI/UX, SSAD 제출 PDF
    pptx/                           # 최신 UI/UX 편집 원본
  docs/
    submission/                     # 시연 촬영 안내와 제출 자료
    user-test/                      # 사용자 테스트 계획·기록 양식
  01_Jammanbo_SSRD.docx             # SSRD 편집 원본
  02_Jammanbo_UIUX.pptx             # UI/UX 이전 편집본
  03_Jammanbo_SSAD.docx             # SSAD 편집 원본
  04_Jammanbo_Prototype.html        # 이전 웹 프로토타입 참고본
  05_Jammanbo_Customer_Validation.docx # 고객 테스트 계획 초안
  docs/user-test/Customer_Test_Packet.md # 진행자용 테스트·기록 패킷
  docs/submission/One_Minute_Demo_Script.md # 60초 시연 대본·촬영 체크리스트
```

## 빌드 및 실행

요구 도구는 Xcode 27 이상과 XcodeGen 2.46 이상입니다.

```sh
xcodegen generate
open Jammanbo.xcodeproj
```

Xcode에서 `Jammanbo` scheme을 iPhone 시뮬레이터로 빌드하거나 페어링된 iPhone·Apple Watch에 실행합니다. 실제 기기에 설치할 때는 Apple Developer Team 서명이 필요합니다. HealthKit 실제 기록 조회와 WatchConnectivity 전달은 페어링된 기기에서 확인해야 합니다.

빌드 명령:

```sh
xcodebuild -project Jammanbo.xcodeproj \
  -scheme Jammanbo \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO build
```

## 진행 상태

- SSRD·UI/UX·SSAD PDF를 만들었습니다.
- SSRD·SSAD 편집 원본 DOCX를 현재 앱 범위와 제출 PDF에 맞춰 동기화했습니다.
- iOS·watchOS를 포함하는 Xcode 프로젝트가 있으며, 기기용 빌드는 성공했습니다.
- 페어링된 실제 기기에서 HealthKit 기록 조회와 체크인 전달을 검증해야 합니다.
- 60초 시연 대본과 촬영 체크리스트는 `docs/submission/One_Minute_Demo_Script.md`에 준비했습니다. 영상 촬영과 YouTube 업로드는 아직 하지 않았습니다.
- 테스트 과업·동의 문구·기록 양식은 `docs/user-test/Customer_Test_Packet.md`에 준비했습니다. 실제 참여자 테스트와 데이터 분석 보고서는 아직 진행하지 않았습니다.

## 개인정보 및 공개 시연

- 실제 사용자 테스트 전 수집 항목과 목적을 설명하고 동의를 받습니다.
- 식별 가능한 참여자 정보와 원자료는 저장소에 올리지 않습니다.
- 공개 시연 영상은 합성 데이터로 촬영하고 개인 정보가 화면에 노출되지 않도록 합니다.
- 예시 화면의 수치는 실제 사용자 측정 결과가 아닙니다.
