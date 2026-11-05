# 플랫폼 결정안

**상태:** 사용자 선택 완료.  
**작성일:** 2026-11-02

## 확정된 선택

`Apple Watch 전용 앱`은 두 가지 뜻으로 쓰일 수 있다.

1. Apple Watch 사용자를 위한 네이티브 서비스로 개발한다.
2. iPhone 앱 없이 Apple Watch에서만 실행되는 watchOS 앱을 만든다.

사용자는 **iPhone 앱 + Apple Watch 동반 앱**을 선택했다. 잠만보는 수면 기록을 빠르게 남기는 것뿐 아니라, 기록 이력·추세·질의응답·캘린더 계획·상담용 요약까지 제공하므로 두 기기의 역할을 나눈다.

## 검토한 선택지

| 선택지 | 장점 | 현재 프로젝트와의 맞음 |
|---|---|---|
| HTML 웹 프로토타입 유지 | 화면과 기록 흐름을 빠르게 확인할 수 있음 | HealthKit 직접 연동과 Apple Watch 경험을 제출 프로토타입에서 보여주기 어려움 |
| Watch-only 앱 | 손목에서 바로 열고 짧게 입력할 수 있음 | 제한된 화면에서 상세 추세, 긴 질의, 주간 계획 편집, 상담용 PDF까지 처리해야 함 |
| iPhone 네이티브 앱만 구현 | HealthKit 기록, 차트, 글과 요약 검토에 적합 | 수면 직후의 손목 입력 경험을 제공하지 못함 |
| iPhone 앱 + watchOS 동반 앱 | iPhone에서 기록 분석·계획·요약을 다루고 Watch에서 빠른 확인·입력을 제공 | 현재의 전체 서비스 가치와 가장 잘 맞음 |

## 제품 구조

**잠만보를 iPhone 중심의 네이티브 앱으로 만들고, Apple Watch에 짧은 체크인과 요약 화면을 제공한다.**

Apple은 Watch 앱을 빠른 상호작용과 핵심 기능에 집중하도록 안내하고, Watch에서 수집한 데이터의 이력과 자세한 추세 분석을 제공하는 경우 iPhone 동반 앱을 고려할 수 있다고 설명한다. HealthKit은 iPhone과 Apple Watch의 건강·운동 데이터를 앱에서 사용자 권한에 따라 다루는 프레임워크다. 참고: [Apple Developer: Build a productivity app for Apple Watch](https://developer.apple.com/videos/play/wwdc2022/10133/), [Apple Developer: HealthKit](https://developer.apple.com/documentation/healthkit/), [Apple Developer: Creating independent watchOS apps](https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps).

### 기능을 기기별로 나누는 안

**iPhone 앱**

- HealthKit 권한 설명 및 수면 기록 조회
- 날짜별 이력, 추세와 생활습관 비교
- 기록에 대한 질문과 근거 항목 확인
- 캘린더와 수면 목표를 이용한 계획 생성·수정
- 상담용 기간 요약 확인과 PDF 내보내기
- 동의·데이터 삭제·내보내기 설정

**Apple Watch 앱**

- 기상 후 느낌과 특이사항을 몇 번의 탭으로 선택
- 전날 수면시간과 오늘 계획을 짧게 확인
- 필요할 때 체크인 리마인더 또는 위젯/컴플리케이션 제공

Watch 체크인은 WatchConnectivity 큐 전송(`transferUserInfo`)으로 iPhone에 전달한다. HealthKit은 수면 분석 카테고리를 읽어 날짜별 수면시간과 단계를 보여준다. 권한 거부, 데이터 없음, Apple Watch가 없는 경우에도 샘플 기록 또는 iPhone 체크인으로 핵심 흐름을 시연할 수 있다.

## 구현 상태 (2026-11-02)

- XcodeGen 프로젝트에 iOS 앱과 단일 타깃 watchOS 앱을 추가했다.
- iPhone 앱: HealthKit 읽기 흐름, 샘플 기록, 최근 7일 추세, 직접 체크인, 개인 기록 기반 규칙형 답변, 수면 목표·일정 입력, 상담 요약 PDF 공유
- Watch 앱: 기분·스트레스·카페인 빠른 체크인과 iPhone으로의 WatchConnectivity 전달
- 두 앱이 들어 있는 iOS 기기용 빌드는 Xcode 27.1 SDK에서 성공했다. 시뮬레이터 실행과 실제 기기 사용성은 아직 확인하지 못했다.
- 수면·체크인·일정은 로컬 저장을 사용한다. 실제 캘린더 동기화, LLM, 서버, 계정·클라우드 백업은 구현하지 않았다.

## 산출물에 미치는 영향

- **SSRD:** HealthKit 읽기와 샘플 대체 경로, Watch 체크인과 iPhone 기능의 요구사항·인수 기준을 PDF에 반영했다.
- **UI/UX:** Watch 체크인 흐름과 iPhone의 이력·분석·계획·상담 요약 화면을 편집 가능한 PPTX와 PDF에 반영했다.
- **SSAD:** HealthKit 권한·WatchConnectivity 전달·로컬 저장 구조와 구현 범위를 PDF에 반영했다.
- **프로토타입:** 현재 HTML은 아이디어 검토용으로 보존한다. 최종 작동 프로토타입은 네이티브 앱을 기준으로 시연한다.
- **고객 검증:** 실제 Apple Watch 사용자에게 Watch 입력과 iPhone 분석 화면을 함께 시험하도록 과업을 설계한다.

## 구현·검증 확인 항목

1. 수업 평가 기준이 `watchOS 앱`을 실제로 요구하는지 확인한다.
2. 팀에서 테스트에 사용할 수 있는 iPhone과 Apple Watch 기기·OS 버전을 확인한다.
3. 실제 기기에서 HealthKit 권한 요청과 수면 기록 조회를 먼저 검증한다.
4. iPhone 앱·Watch 앱 설치 및 배포 방식과 마감일을 확인한다.
5. Watch 데이터 동기화, LLM 요청 범위, 사용자 인증 여부를 SSAD에서 결정한다.

Watch-only 앱으로 바꾸는 것은 현재 선택과 다르다. 수업 조건에 변경이 생길 때만 별도 결정으로 다시 검토한다.

## 다음 검증

현재 iOS·watchOS 대상 빌드는 성공했다. 실제 HealthKit 권한 및 기록 조회, WatchConnectivity 전달, 화면 사용성은 페어링된 기기에서 검증해야 한다. 고객 테스트와 공개 시연도 실제 앱 상태에 맞춰 진행한다.
