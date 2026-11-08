/** Focused edits to the existing, editable UI/UX deck. Requires the Codex artifact runtime.
 * Use scripts/sync_submission_deck.sh to link the bundled runtime dependencies.
 * Usage: node sync_submission_deck.mjs SOURCE.pptx WORKSPACE
 * The validated file is written to WORKSPACE/final/02_Jammanbo_UIUX_v7.pptx.
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {FileBlob,PresentationFile} from '@oai/artifact-tool';
const source=path.resolve(process.argv[2]);
const workspaceDir=path.resolve(process.argv[3]);
const runtime=process.env.JAMMANBO_ARTIFACT_RUNTIME??'/Users/jinwoong/.cache/codex-runtimes/codex-primary-runtime';
process.env.RUNTIME_NODE_MODULES ??= path.join(runtime,'dependencies/node/node_modules');
const SKILL_DIR=process.env.JAMMANBO_PRESENTATIONS_SKILL ?? path.join(runtime,'plugins/openai-primary-runtime/plugins/presentations/skills/presentations');
const p=await PresentationFile.importPptx(await FileBlob.load(source));
const before=await p.inspect({kind:'slide,textbox,shape,image,table',maxChars:250000});
await fs.mkdir(path.join(workspaceDir,'build'),{recursive:true});
await fs.mkdir(path.join(workspaceDir,'final'),{recursive:true});
await fs.writeFile(path.join(workspaceDir,'build','before.ndjson'),before.ndjson);
// IDs come from inspect of the source deck, not guessed slide indexes.
const updates={
'sh/7qp4be9c':'HealthKit 수면과 생활습관을 연결하는 iPhone + Watch 앱\nP03·P05 피드백 반영 · v1.4 · 2026-11-08',
'sh/ove9o7yd':'수면 + 운동 포함 체크인 + 계산 근거 + 일정 반영 취침 제안 + 선택·동의 공유',
'sh/nu58f2hs':'비교 기준 이해, 자정 일정 반영, 공유 범위와 최종 동의를 사용자가 확인하는지 검증',
'sh/pcjqtg36':'수면 + 운동 포함 습관',
'sh/a5c3ql8z':'표현 변형·비교 기준',
'sh/i9w3u58v':'기상일·목표·종료 일정',
'sh/14ryd8fq':'선택 → 확인 → 동의',
'sh/6d0fytg3':'현재: 운동·근거 비교, 수동 일정 충돌, 선택 PDF·동의. 외부 캘린더와 생성형 LLM은 후속 범위',
'sh/kbm987y5':'• 기분·스트레스\n\n• 오후 카페인\n\n• 운동 3가지 상태\n\n• 폰 / Watch 입력',
'sh/jadsz2xk':'• 표현 변형 인식\n\n• 평균·차이·일수\n\n• 날짜·출처·기준\n\n• 미기록·샘플 제외',
'sh/a5kr2xg3':'• 기상일·수면 목표\n\n• 일정 시작·종료\n\n• 종료 후 30분\n\n• 부족·대안 기상',
'sh/h4fa9wfy':'• 최근 7일 요약\n\n• 날짜·항목 선택\n\n• PDF 미리보기\n\n• 최종 동의·공유',
'sh/3i94r61s':'• 데이터 출처와 샘플을 알아보는가?\n• 최근 평균과 목표 달성률을 이해하는가?\n• 다음 행동을 찾는가?',
'sh/47mt0b6x':'운동  미기록 / 없음 / 있음',
'sh/i54bylor':'iPhone 저장 · 이력 수정·삭제',
'sh/qpwnet0b':'운동을 함께 기록하고 이력에서 수정·삭제한다.\n구형 기록은 운동 미기록으로 유지한다.',
'sh/lg76d8zy':'T2a: 운동 3가지 상태·수정·재실행\nT2b: Watch 운동 전달·폰 확인',
'sh/gju58ji9':'• 운동 미기록을 ‘없음’으로 바꾸지 않음\n• 비교에서 운동 미기록 제외\n• 체크인 최근 30건, 원래 시각·출처 유지\n• Watch는 폰 저장 확인까지 재시도\n• 실제 Watch 전달은 기기 재시험 필요',
'sh/baxkjqlk':'운동 여부\n미기록 / 없음 / 있음',
'sh/50v2pgna':'기분 · 스트레스 · 카페인 · 운동',
'sh/id4ju1oz':'폰 저장 확인 전까지 보관·재시도',
'sh/f6xkvq5c':'운동 누락은 미기록으로 보존한다. 분석·계획·선택 PDF는 iPhone에서 확인한다.\n운동 payload와 저장은 구현했으며 실제 Watch 전달은 재시험한다.',
'sh/id0fu50z':'운동한 날 수면이 달랐나?',
'sh/98rehwve':'운동 있음 2일 · 없음 1일\n비교할 기록이 더 필요해요.\n(설명용 예시)',
'sh/n6pwfmd8':'비교 기준 보기',
'sh/1k7edwv2':'실제 수면 · 조건별 최소 2일',
'sh/zipwbmdc':'최근 7일 · 운동 미기록 제외',
'sh/tw7e9gnq':'운동·산책·러닝·workout 표현을 인식한다.\n같은 기상일의 최신 체크인과 결합하고\n조건별 실제 기록 2일 이상만 비교한다.',
'sh/6twve1oz':'T3: P03 문구·표현 변형·복합 질문 확인\n평균·차이·일수·날짜·출처와 기준 찾기',
'sh/kredcr6t':'비교 기준과 해석',
'sh/jq5w365o':'• 운동 있음 / 없음, 카페인, 스트레스 비교\n• 운동 미기록·샘플 수면 제외\n• 두 평균·차이·각 일수·날짜·출처 표시\n• 2일은 계산 최소치, 유의성 기준 아님\n• 인과관계·임상 효과를 판단하지 않음\n• 운동 종류·강도별 분석은 미제공\n• 여러 습관이면 하나를 고르도록 안내',
'sh/ofq5svm5':'다음 날 기상 계획',
'sh/ah8nu54b':'기본 23:00 → 제안 00:30\n기상 07:00 · 설명용 예시',
'sh/p0ji9kf2':'목표 수면 8시간',
'sh/3y107axw':'약속 22:00 ~ 00:00',
'sh/do3id4fy':'확보 6h30 · 1h30 부족\n8h 유지 대안 기상 08:30',
'sh/bml0buxs':'목표·일정 수정',
'sh/98ji147e':'기상일·목표로 기본 취침을 계산한다.\n충돌 일정의 최종 종료 + 30분으로 조정하고\n확보·부족 시간과 대안 기상을 표시한다.',
'sh/ml8j6p8n':'T4: 07:00·8시간, 22:00~00:00 일정\n00:30·6h30·부족 1h30·대안 08:30 확인',
'sh/wba1cjqp':'예외와 범위',
'sh/va103ep4':'• 목표 자체를 몰래 변경하지 않음\n• 일정 추가·삭제 즉시 다시 계산\n• 여러 충돌은 마지막 종료를 반영\n• 잘 시간 없으면 0분과 조정 안내\n• 구형 종료 누락: 1시간 보완·안내\n• 외부 캘린더·주간 최적화 미제공',
'sh/cbu58j2h':'선택한 기록의 PDF와 최종 동의',
'sh/kzu5c32t':'공유할 데이터 선택',
'sh/m1cnetkj':'① 최근 7일 중 날짜\n② 수면·단계·체크인 항목',
'sh/d87uxg3m':'기본: 총 수면·평균만 포함',
'sh/r6pcv6lw':'③ 선택한 PDF 확인',
'sh/1cru1g3y':'④ □ 선택 내용의 최종 공유 동의\n처음에는 체크되지 않음',
'sh/fapcz6ls':'동의하고 공유 대상 선택',
'sh/xwnupgvy':'날짜·항목 선택 → 로컬 PDF 확인 → 최종 동의\n→ 시스템 시트에서 앱·수신자·전송 결정.\n선택 자료가 많으면 여러 페이지로 출력한다.',
'sh/atwbelcn':'T5: 하루 운동만 PDF·미선택 값 제외\n미동의 차단·취소 재동의·변경 시 무효화',
'sh/jypcrqd4':'• 단계·체크인은 기본 제외\n• 기분·스트레스·카페인·운동 개별 선택\n• 선택값만 생성기에 전달, 원본 숨김 없음\n• 문서 ID·현재 기록·동의 확인 후 개방\n• 공유 시트 개방 즉시 동의 초기화\n• 취소 후 재동의, 자동 전송 없음\n• 미선택 체크인 개수도 출력하지 않음',
'sh/o7ih0r6h':'수면이 없으면 샘플 출처를 표시한다.\n단계 미제공과 0분은 다르다.\n운동 미기록은 비교에서 제외한다.\n조건별 2일 미만이면 일수·날짜와\n추가 기록 안내를 표시한다.',
'sh/ofqtgnyt':'일정 때문에 잘 시간이 없으면 확보 0분과 조정 안내.\nPDF 무항목 선택은 생성 차단.\n기록·선택 변경 시 기존 PDF·동의 무효화.\n공유 취소 후에는 다시 동의해야 한다.',
'sh/nehs7iho':'Watch는 폰 저장 확인까지 보관·재시도한다.\n건강 연결 후 복귀·기록 변경 시 재조회.\n질문 답변도 기록 내용 변경에 맞춰 갱신한다.\n로딩·샘플·확인 대기 상태를 구분한다.',
'sh/0f2lgnmp':'P03·P05 개선 후 고객 재시험 계획',
'sh/b6d4f2lc':'• P03·P05 개선 후 재시험 예정\n• 과업 완료율·소요시간\n• 오류·도움 요청 수\n• 비교 기준 이해·신뢰도 1~5\n• 공유 범위·동의 이해 여부\n• 재사용 의향·반복 의견\n• 개발 검증과 고객 결과 분리',
'sh/32ponyts':'✓ 운동 미기록 구분·폰 / Watch 체크인\n✓ 표현 변형·비교 근거와 기준\n✓ 종료 일정 반영·부족·대안 기상\n✓ 날짜·항목 선택 PDF·최종 동의\n✓ 다중 페이지·오래된 PDF 차단\n✓ 기기 내 목표·체크인·일정 저장',
'sh/hcfy9k3u':'→ P03·P05의 개선 후 고객 재시험\n→ 실제 HealthKit·Watch 운동 전달 확인\n→ 외부 캘린더 연동\n→ 생성형 LLM 설명·요약\n→ 계정·보호·장기 추세\n→ 리마인더·알림',
'sh/gb6x0zm9':'2026-11-08 v1.4 · 개발 검증 완료와 고객 재시험 전 상태를 구분한다. 화면 수치는 설명용 예시다.'
};
Object.assign(updates, {
  "sh/7qp4be9c": "HealthKit 수면과 생활습관을 연결하는 iPhone + Watch 앱\nLLM API 연동 설계안 반영 · v1.5 · 2026-11-08",
  "sh/ove9o7yd": "수면·습관 기록 + 근거 설명 + 일정 반영 + 선택 공유. LLM API로 설명·요약을 확장하는 설계안",
  "sh/a5c3ql8z": "로컬 근거 + LLM API안",
  "sh/6d0fytg3": "v1.5 API 설계안: 선택 자료·동의 → 중계 서버 → LLM 설명. 현재 앱·영상은 로컬 규칙 기반",
  "sh/jadsz2xk": "• 현재 로컬 계산\n\n• 날짜·출처·기준\n\n• LLM API 설계안\n\n• 전송 확인·동의",
  "sh/g72x4zyd": "LLM 질문과 설명 API 연동안",
  "sh/sjix0zy1": "선택 기록에 질문",
  "sh/98rehwve": "LLM 설명 응답 예시\n수치는 선택 기록 기준\n(API 연동 설계안)",
  "sh/n6pwfmd8": "전송 자료 확인과 동의",
  "sh/1k7edwv2": "선택한 맥락만 API로 전송",
  "sh/zipwbmdc": "실패 시 로컬 결과로 복귀",
  "sh/lgbepgvm": "제안하는 API 흐름",
  "sh/tw7e9gnq": "질문·선택 사실 → 전송 동의 → 중계 서버\n→ LLM 설명 → 근거·수치 확인.\n현재 앱의 API 호출은 미구현·미검증이다.",
  "sh/6twve1oz": "T6 설계: 선택·동의·근거·정상/오류 응답\n현재 로컬 T3 및 기존 고객 수치와 분리",
  "sh/kredcr6t": "근거와 데이터 경계",
  "sh/jq5w365o": "• 수치는 로컬 계산, LLM은 설명 작성\n• 질문·선택 기록의 전송 범위 확인\n• 외부 처리 동의와 PDF 공유 동의 분리\n• 공급자 키는 중계 서버에 보관하는 안\n• 응답 근거 ID·수치와 생성 표시 확인\n• 취소·지연·한도 오류는 별도 안내\n• 공급자·모델·배포는 미정, 실측 전",
  "sh/xwnupgvy": "현재: 선택 → PDF 확인 → 최종 동의·대상 선택.\nAPI안: 선택 자료의 LLM 요약 초안을 검토한 뒤\nPDF에 포함하며 전송 동의는 따로 받는다.",
  "sh/ofqtgnyt": "현재: 일정 수면 0분·무선택 PDF·취소 안내.\nAPI안: 미동의 요청 차단, 로딩·취소·오프라인,\n시간 초과·인증·한도·응답 오류를 구분한다.\n실패 시 현재 로컬 기능을 유지한다.",
  "sh/b6d4f2lc": "• 현재 T1~T5와 API안 T6·T7 분리\n• 과업 완료율·시간·도움·오류\n• 근거 이해·생성 설명 구분\n• 외부 전송 범위·동의 이해\n• API 지연·실패·제외값 검증 계획\n• API 실제 호출·고객 재시험 전\n• 기존 6명·105개를 API 성과로 미사용",
  "sh/bq9orito": "현재 구현과 LLM API 추가 설계",
  "sh/1076lobm": "LLM API 설계안",
  "sh/hcfy9k3u": "→ 선택 기록·질문과 외부 처리 동의\n→ 중계 서버를 통해 LLM API 호출\n→ 근거가 표시된 설명·요약 초안\n→ 사용자 검토 후 PDF 포함\n→ 오류 시 로컬 결과 사용\n→ 실제 연결·응답·고객 검증은 수행 전",
  "sh/gb6x0zm9": "v1.5 · LLM API는 설계 가정이며 실제 호출 미검증. 현재 앱·영상의 질문은 로컬 규칙으로 동작한다."
});
for(const [id,value] of Object.entries(updates)) {
 const target=p.resolve(id);
 const old=String(target.text);
 // Replacing the whole text range retains the imported frame and its first run style.
 target.text.replace(old,value);
}
const table=p.resolve('tb/pk3y1ovi');
const rows=[['ID','과업','성공 기준'],['T1·T2','수면·운동 체크인','출처·미기록·저장·수정'],['T3','운동 질문·근거','표현 변형·일수·계산 기준'],['T4','자정 일정 반영','00:30·부족·대안 08:30'],['T5','선택 PDF·최종 동의','미선택 제외·취소 재동의']];
rows.forEach((r,i)=>r.forEach((v,j)=>table.cells.set(i,j,v)));
// Source uses this Korean typeface in its explicit East Asian runs. Keep all frames and sizes.
for(const s of p.slides.items) {
 for(const shape of s.shapes.items) {if(String(shape.text??'').length) shape.text.style={typeface:'Apple SD Gothic Neo'};}
}
for(let r=0;r<5;r++) for(let c=0;c<3;c++) table.getCell(r,c).text.style={typeface:'Apple SD Gothic Neo'};
const after=await p.inspect({kind:'slide,textbox,shape,image,table',maxChars:250000});
await fs.writeFile(path.join(workspaceDir,'build','after.ndjson'),after.ndjson);
for(const [n,s] of p.slides.items.entries()) {
 const png=await s.export({format:'png',scale:1});
 await fs.writeFile(path.join(workspaceDir,'build',`slide-${n+1}.png`),new Uint8Array(await png.arrayBuffer()));
 const layout=await s.export({format:'layout'});
 await fs.writeFile(path.join(workspaceDir,'build',`slide-${n+1}.json`),await layout.text());
}
const candidatePath=path.join(workspaceDir,'build','candidate.pptx');
await (await PresentationFile.exportPptx(p)).save(candidatePath);
const {finalizePresentation}=await import(pathToFileURL(path.join(SKILL_DIR,'container_tools/artifact_tool_utils.mjs')).href);
const result=await finalizePresentation({workspaceDir,candidatePath,
 finalPath:path.join(workspaceDir,'final','02_Jammanbo_UIUX_v7.pptx'),
 pythonExecutable:path.join(runtime,'dependencies/python/bin/python3.12'),
 integrityValidatorPath:path.join(SKILL_DIR,'container_tools/inspect_presentation_package_integrity.py'),
 layoutValidatorPath:path.join(SKILL_DIR,'container_tools/inspect_presentation_layout_geometry.py'),
 layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-bullet-geometry','--validate-heading-fit','--require-native-table-slide','12'],
 requiredNativeTableOwnerSlides:[12],
 fontPolicy:{basis:'reference',families:['Apple SD Gothic Neo'],referencePath:source,referenceSha256:crypto.createHash('sha256').update(await fs.readFile(source)).digest('hex')},
 verifyArtifactToolImport:true,
 receiptPath:path.join(workspaceDir,'build','validation.json')});
console.log(JSON.stringify(result));
