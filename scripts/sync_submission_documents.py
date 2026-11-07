"""Synchronize submission sources; run with the Codex artifact runtime Python.

DOCX uses python-docx. PPTX text edits preserve the current root deck's layout and shapes.
PDF export and visual inspection are separate steps.
"""
from pathlib import Path
from copy import deepcopy
from zipfile import ZipFile, ZIP_DEFLATED
import re
from lxml import etree
from docx import Document
from docx.shared import Cm, Pt, RGBColor
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT = Path(__file__).resolve().parents[1]
FONT = 'Apple SD Gothic Neo'

def plain(s):
    s = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', s)
    return s.replace('**', '').replace('`', '').strip()

def font(run, size=None):
    run.font.name = FONT
    run._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'), FONT)
    if size is not None: run.font.size = Pt(size)

def base_document(title):
    d = Document()
    sec = d.sections[0]
    sec.page_width, sec.page_height = Cm(21), Cm(29.7)
    sec.top_margin = sec.bottom_margin = Cm(1.7)
    sec.left_margin = sec.right_margin = Cm(1.65)
    for name, size in [('Normal',10.3),('Title',24),('Heading 1',16),('Heading 2',12),('Caption',9)]:
        st=d.styles[name];st.font.name=FONT;st.font.size=Pt(size);st.font.color.rgb=RGBColor(0,0,0)
        st._element.get_or_add_rPr().get_or_add_rFonts().set(qn('w:eastAsia'),FONT)
        st.paragraph_format.space_after=Pt(6)
    d.styles['Normal'].paragraph_format.line_spacing=1.13
    d.styles['Heading 1'].paragraph_format.space_before=Pt(8)
    d.styles['Heading 2'].paragraph_format.space_before=Pt(7)
    for st in d.styles:
        for border in list(st._element.iter(qn('w:pBdr'))): border.getparent().remove(border)
    d.core_properties.title=title
    d.core_properties.author='Team 17'
    d.add_paragraph(title,'Title')
    return d

def table(d, rows):
    compact=d.core_properties.title.startswith('잠만보 소프트웨어')
    t=d.add_table(rows=1, cols=len(rows[0]));t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
    n=len(rows[0]);widths=({2:[4.2,13.3],3:[3.2,7.5,6.8],4:[2.0,6.5,3.3,5.7],7:[1.6,1.7,2.0,1.4,1.5,2.8,6.5]}.get(n,[17.5/n]*n))
    if rows[0][0] == '질문': widths=[14.2,3.3]
    if rows[0][0] == '요약 지표': widths=[10.5,7.0]
    for col,w in zip(t.columns,widths): col.width=Cm(w)
    for i,row in enumerate(rows):
        cells=t.rows[0].cells if i==0 else t.add_row().cells
        for j,(cell,text) in enumerate(zip(cells,row)):
            cell.width=Cm(widths[j]);cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
            p=cell.paragraphs[0];p.paragraph_format.space_after=Pt(1 if compact else 3);p.paragraph_format.space_before=Pt(1 if compact else 3);p.paragraph_format.line_spacing=1.08
            r=p.add_run(plain(text));font(r,9.1);r.bold=i==0
            if i==0:r.font.color.rgb=RGBColor(255,255,255)
            pr=cell._tc.get_or_add_tcPr();sh=OxmlElement('w:shd');sh.set(qn('w:fill'),'344C61' if i==0 else ('F4F6F8' if i%2==0 else 'FFFFFF'));pr.append(sh)
            margins=OxmlElement('w:tcMar')
            for side in ['top','left','bottom','right']:
                e=OxmlElement('w:'+side);e.set(qn('w:w'),'80');e.set(qn('w:type'),'dxa');margins.append(e)
            pr.append(margins)
            borders=OxmlElement('w:tcBorders')
            for side in ['top','left','bottom','right']:
                e=OxmlElement('w:'+side);e.set(qn('w:val'),'single');e.set(qn('w:sz'),'4');e.set(qn('w:color'),'D9D9D9');borders.append(e)
            pr.append(borders)
        trpr=t.rows[i]._tr.get_or_add_trPr();trpr.append(OxmlElement('w:cantSplit'))
        if i==0: trpr.append(OxmlElement('w:tblHeader'))
    spacer=d.add_paragraph()
    spacer.paragraph_format.space_after=Pt(0 if compact else 2)
    if compact:
        spacer.paragraph_format.space_before=Pt(0)
        spacer.paragraph_format.line_spacing=Pt(1)
        font(spacer.add_run(''),1)
    return t

def from_markdown(path, output, title, page_sections=()):
    d=base_document(title);lines=path.read_text().splitlines();i=0
    while i<len(lines):
        line=lines[i].strip()
        if not line or line.startswith('# '): i+=1;continue
        if line.startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].strip().startswith('|'):
                row=[x.strip() for x in lines[i].strip().strip('|').split('|')]
                if not all(re.fullmatch(r':?-+:?',x) for x in row):rows.append(row)
                i+=1
            table(d,rows);continue
        if line.startswith('!['):
            m=re.match(r'!\[([^]]*)\]\(([^)]+)\)',line)
            p=d.add_paragraph();r=p.add_run();pic=r.add_picture(str(path.parent/m.group(2)),width=Cm(17.5));pic._inline.docPr.set('descr',m.group(1));d.add_paragraph(m.group(1),'Caption');i+=1;continue
        if line.startswith('## '):
            heading=plain(line[3:])
            hp=d.add_paragraph(heading,'Heading 1')
            if heading in page_sections: hp.paragraph_format.page_break_before=True
            i+=1;continue
        if line.startswith('### '): d.add_paragraph(plain(line[4:]),'Heading 2');i+=1;continue
        if line.startswith('>'):line=line.lstrip('> ').strip()
        p=d.add_paragraph(plain(line));
        for r in p.runs:font(r)
        i+=1
    if output.name.startswith('05_'):
        from docx.text.paragraph import Paragraph
        for t in d.tables:
            previous=t._tbl.getprevious()
            if previous is not None and previous.tag==qn('w:p'):
                Paragraph(previous,d).paragraph_format.keep_with_next=True
            for c in t.rows[0].cells:
                for paragraph in c.paragraphs: paragraph.paragraph_format.keep_with_next=True
    d.save(output)

# The architecture Markdown is the editable text source for the integrated SSAD.
arch=ROOT/'docs/architecture/Application_Structure.md'
sections=[plain(x[3:]) for x in arch.read_text().splitlines() if x.startswith('## ') and not x.startswith('## 6 ')][1:]
from_markdown(arch, ROOT/'03_Jammanbo_SSAD.docx','잠만보 소프트웨어 구조와 애플리케이션 설계',sections)
from_markdown(ROOT/'docs/user-test/Customer_Test_Packet.md', ROOT/'05_Jammanbo_Customer_Validation.docx','잠만보 고객 사용성 검증 계획과 기록 양식',('3. 참여 안내 및 동의 문구','9. 빈 결과 요약 양식'))

# Update the existing SSRD without discarding its requirement identifiers.
p=ROOT/'01_Jammanbo_SSRD.docx';d=Document(p)
replacements={
'2026-11-02':'2026-11-07','v1.1':'v1.3','v1.2':'v1.3',
'최근 7일 수면 흐름과 저장된 체크인을 확인한다. 수면 기록 편집·삭제는 제공하지 않는다.':'최근 7일 수면 상세와 체크인 전체 이력을 조회한다. 체크인은 수정·삭제하며 건강 원본은 읽기 전용이다.',
'날짜별 기록 목록에서 최근 자료를 확인할 수 있다.':'수면 7일과 체크인 최근 30건을 조회하고, 체크인 수정·삭제 결과가 재실행 후 유지된다.',
'iPhone 저장과 출처를 확인한다. Watch는 실제 수신까지 확인하며 동일 UUID 재전송은 중복 저장하지 않는다.':'Watch는 iPhone 저장 확인까지 큐를 유지하고 실패 시 재시도한다. 기록 시각순 보관과 UUID 중복 방지를 확인한다.',
'읽을 수 있는 기록을 조회한다. 기록이 없거나 오류가 나면 출처와 안내를 갖춘 샘플 상태를 표시한다.':'연결 후 실행·복귀·변경 시 재조회한다. 수면은 겹침을 제거하고 기상일로 집계하며 빈 결과는 샘플 출처를 표시한다.',
'최근 7일 범위와 출처가 있는 PDF를 생성한 뒤 공유 버튼을 표시한다. 공유 대상은 사용자가 선택한다.':'앱 내부 PDF 미리보기에서 기간·출처를 확인한다. 기록 변경 시 무효화하고 공유 시 최신 PDF를 생성한다.',
'최근 수면 기록의 날짜, 총 수면시간, 제공되는 수면 단계를 표시한다. 샘플 기록은 샘플 출처임을 구분한다.':'최근 7일 수면의 날짜, 총 시간과 제공된 단계를 표시한다. 미분류 수면과 단계 미제공을 구분하고 샘플 출처를 표시한다.',
'체크인·목표·수동 일정은 현재 기기에 보관한다. 서버 계정은 없다.':'체크인 최근 30건과 목표·일정은 UserDefaults에 저장한다. 수면 조회 결과는 메모리에 보관한다.',
'양쪽 그룹의 기록이 없으면 차이를 계산하지 않고 체크인 필요를 안내한다.':'조건별로 최소 2일의 실제 수면·체크인 결합 기록이 필요하다. 샘플 수면과 개인 체크인은 비교하지 않는다.',
'같은 날짜의 수면 기록과 체크인이 충분한 경우에만 카페인 또는 스트레스 그룹별 평균 수면시간을 비교한다.':'같은 날짜의 실제 수면과 하루 최신 체크인을 결합해 카페인 또는 스트레스 조건별 평균을 비교한다.',
'Watch에서 저장한 체크인이 연결 후 iPhone에 도착하며 출처를 구분할 수 있다.':'iPhone 저장과 출처를 확인한다. Watch는 실제 수신까지 확인하며 동일 UUID 재전송은 중복 저장하지 않는다.',
'체크인·목표·일정은 현재 기기에 보관한다. 서버 계정은 없다.':'체크인은 최근 30건, 목표·일정은 UserDefaults에 보관한다. 수면 조회 결과는 메모리 상태다. 서버 계정은 없다.',
'권한 허용 시 실제 HealthKit 자료를 조회하고, 거부 시 안내와 대체 상태를 표시한다.':'읽을 수 있는 기록을 조회한다. 기록이 없거나 오류가 나면 출처와 안내를 갖춘 샘플 상태를 표시한다.',
'목표 수면시간과 목표 기상 시각을 사용해 취침 목표를 계산한다.':'목표 수면 360~600분과 기상 시각으로 취침 목표를 계산한다. 수동 일정은 계산에 자동 반영하지 않는다.',
'답변 카드에 근거 범위 또는 체크인 부족 상태가 보인다.':'답변에 날짜·출처가 보이며 비교에서는 각 조건의 기록 수와 자료 부족 상태를 확인한다.',
'PDF 미리보기가 생성되고 사용자가 공유 앱·수신자를 선택한다. JSON/CSV 내보내기는 미지원이다.':'최근 7일 범위와 출처가 있는 PDF를 생성한 뒤 공유 버튼을 표시한다. 공유 대상은 사용자가 선택한다.',
'앱 타깃은 iOS Simulator와 iOS 기기·Watch 포함 generic build를 통과했다. 실제 iPhone·Watch 상호작용과 사용자 테스트는 기기에서 추가 검증해야 한다.':'서명 없는 iPhone·Watch 빌드와 계산·저장 경계 검사를 수행한다. iPhone 실행은 사용자 보고로 확인했고 실제 HealthKit·Watch 전달·고객 과업은 별도 검증한다.'
}
def paras(container):
    yield from container.paragraphs
    for t in container.tables:
        for row in t.rows:
            for c in row.cells: yield from paras(c)
for paragraph in paras(d):
    old=paragraph.text;new=old
    for a,b in replacements.items():new=new.replace(a,b)
    if new!=old:
        first=paragraph.runs[0] if paragraph.runs else None
        for r in paragraph.runs:r.text=''
        r=paragraph.add_run(new)
        if first is not None and first._r.rPr is not None:r._r.insert(0,deepcopy(first._r.rPr))
        font(r)
for st in d.styles:
    if st.type==1 and ('Heading' in st.name or 'Title' in st.name): st.font.color.rgb=RGBColor(0,0,0)
for paragraph in paras(d):
    for r in paragraph.runs:
        font(r)
        if paragraph.style.name in ['Title','Subtitle'] or paragraph.style.name.startswith('Heading'):r.font.color.rgb=RGBColor(0,0,0)
for paragraph in d.paragraphs:
    if paragraph.text.startswith(tuple(str(i) for i in range(1,10))) or paragraph.style.name in ['Title','Subtitle']:
        for r in paragraph.runs:
            color=r._r.get_or_add_rPr().find(qn('w:color'))
            if color is not None:
                for key in list(color.attrib):
                    if key != qn('w:val'): del color.attrib[key]
                color.set(qn('w:val'),'000000')
if d.paragraphs[0].text == '잠만보':
    d.paragraphs[0].style='Title'
    for r in d.paragraphs[0].runs: r.font.color.rgb=RGBColor(0,0,0)
for t in list(d.tables):
    if len(t.rows)==1 and len(t.columns)==1:
        for paragraph in t.cell(0,0).paragraphs:
            copied=deepcopy(paragraph._p)
            for color in copied.iter(qn('w:color')):
                color.attrib.clear();color.set(qn('w:val'),'000000')
            t._tbl.addprevious(copied)
        t._tbl.getparent().remove(t._tbl)
for sec in d.sections:
    for container in [sec.header,sec.footer]:
        for paragraph in container.paragraphs:
            for r in paragraph.runs:
                r.font.color.rgb=RGBColor(0,0,0)
                color=r._r.get_or_add_rPr().find(qn('w:color'))
                if color is not None:
                    color.attrib.clear();color.set(qn('w:val'),'000000')
for border in list(d.element.iter(qn('w:pBdr'))): border.getparent().remove(border)
for st in d.styles:
    for border in list(st._element.iter(qn('w:pBdr'))): border.getparent().remove(border)
d.core_properties.title='잠만보 요구사항 명세서';d.save(p)
# A text copy makes the requirement IDs available to GitHub code reviewers.
from docx.text.paragraph import Paragraph
from docx.table import Table
md=[]
for element in d.element.body:
    if element.tag==qn('w:p'):
        para=Paragraph(element,d);text=para.text.strip()
        if text:md.append(('## ' if para.style.name.startswith('Heading') else '')+text)
    elif element.tag==qn('w:tbl'):
        t=Table(element,d);rows=[[c.text.replace('\n',' ') for c in row.cells] for row in t.rows]
        for i,row in enumerate(rows):
            md.append('| '+' | '.join(row)+' |')
            if i==0:md.append('| '+' | '.join(['---']*len(row))+' |')
    md.append('')
req=ROOT/'docs/requirements';req.mkdir(exist_ok=True)
(req/'SSRD.md').write_text('# 잠만보 요구사항 명세서\n\n'+'\n'.join(md))

# Preserve the root deck's editable layout, updating labels and validation rules.
ns={'a':'http://schemas.openxmlformats.org/drawingml/2006/main','p':'http://schemas.openxmlformats.org/presentationml/2006/main'}
changes={
'HealthKit 수면과 iPhone 체크인을 연결하는 개인 수면 기록 앱 · Watch는 선택 입력 · v1.2':'HealthKit 수면과 iPhone 체크인을 연결하는 개인 수면 기록 앱 · Watch는 선택 입력 · v1.3',
'Watch 전송 예약과 iPhone 수신 완료를 구분한다. HealthKit 조회는 로딩을 표시하고 실패하면 샘플 목록·출처·안내를 함께 갱신한다.':'Watch는 iPhone 저장 확인까지 보관·재시도한다. 건강 연결 후 앱 복귀·기록 변경 시 조회하고 실패하면 샘플 출처를 표시한다.',
'UUID를 담아 WatchConnectivity로 전송을 예약한다. iPhone 목록에서 실제 도착을 확인한다.':'UUID로 전달·중복 방지. 폰 저장 확인까지 보관하고 실패 시 재시도한다.',
'• Watch 체크인은 예약 후 실제 수신 확인':'• Watch는 폰 저장 확인까지 보관·재시도',
'iPhone에서 기분·스트레스·오후 카페인을 선택해 저장한다.\nWatch는 페어링된 iPhone으로 전달한다.':'iPhone에서 입력하고 전체 이력에서 수정·삭제한다.\nWatch는 폰 저장 확인까지 보관·재시도한다.',
'탭 메뉴로 체크인·계획·요약 이동\n건강 연결 버튼으로 수면 조회\n홈 카드의 탭 이동은 미제공':'최근 7일 전체 목록과 날짜별 상세\n건강 연결 후 복귀·변경 시 갱신\n탭 메뉴로 체크인·계획·요약 이동',
'T5: 최근 7일 요약과 출처 확인\nPDF 생성 후 외부 전송 없이 종료':'T5: PDF 미리보기·출처 확인\n체크인 변경 후 새 PDF 반영 확인',
'T2a: iPhone 체크인 저장과 출처 확인\nT2b: Watch 실제 수신 확인 (선택)':'T2a: 전체 이력·수정·재실행 확인\nT2b: Watch 폰 저장 확인 (선택)',
'HealthKit 수면 기록과 Apple Watch 체크인을 연결하는 개인 수면 관리 앱 · 화면 값은 예시':'HealthKit 수면과 iPhone 체크인을 연결하는 개인 수면 기록 앱 · Watch는 선택 입력 · v1.2',
'T1: iPhone 또는 Watch에서 체크인을 저장하는가?\n목표: 60초 이내 완료 (고객 검증 전)':'T2a: iPhone 체크인 저장과 출처 확인\nT2b: Watch 실제 수신 확인 (선택)',
'T2: 사용자가 계산 범위와 데이터 출처를 찾는가?\n근거 이해도와 답변 신뢰도를 확인한다.':'T3: 계산 날짜·출처와 기록 부족 안내를 찾는가?\n비교 조건별 최소 2일, 샘플 비교 제외',
'T3: 수면 목표와 기상시각을 바꾸는가?\n취침 목표가 다시 계산되는지 확인한다.':'T4: 목표 8시간·07:00 설정 후 23:00 확인\n수동 일정 추가·삭제와 재실행 보관 확인',
'T4: 참가자가 요약 내용을 이해하고 공유 여부를 스스로 결정하는지 확인한다.':'T5: 최근 7일 요약과 출처 확인\nPDF 생성 후 외부 전송 없이 종료',
'현재 답변은 기기 내 규칙 계산이다. 날짜·출처를 표시하고 비교 표본이 부족하면 결과를 추정하지 않는다.':'AnalysisService가 날짜·출처와 근거를 계산한다. 비교 조건별 실제 기록이 2일 이상일 때만 비교하며 샘플 수면은 제외한다.',
'HealthKit 권한을 거부했거나 기록이 없으면 상태를 설명하고 샘플 기록 여부를 표시한다. 체크인이 없으면 비교 가능한 기록이 더 필요하다고 안내한다.':'읽을 수 있는 수면 기록이 없으면 샘플 출처를 표시한다. 단계 미제공은 0분과 구분한다. 비교 조건별 실제 기록이 최소 2일 필요하다.',
'Watch 체크인은 전달 대기 상태를 표시한다. HealthKit 조회와 PDF 생성 중에는 현재 작업 상태를 보여주고 기존 화면을 유지한다.':'Watch 전송 예약과 iPhone 수신 완료를 구분한다. HealthKit 조회는 로딩을 표시하고 실패하면 샘플 목록·출처·안내를 함께 갱신한다.',
'체크인 저장 후 iPhone에 전달':'iPhone 입력은 이 기기에 저장',
'• Watch 체크인은 연결 후 iPhone으로 전달':'• Watch 체크인은 예약 후 실제 수신 확인',
'• 현재 참가자: 0명':'• 실제 결과: 미수집',
'취침 목표 23:00 · 기상 07:00 (예시)':'목표 달성률 90% · 설정 목표 기준 (예시)',
'스트레스  보통 · 높음':'스트레스  낮음 · 보통 · 높음',
'빠른 기록':'Apple 건강 기록 연결',
'취침 목표 예시\n23:00 취침 · 07:00 기상':'수면 목표 예시\n8시간 목표 · 달성률 90%',
'입력 위치  iPhone / Watch':'입력 위치  iPhone',
'기분·스트레스·오후 카페인만 간단히 입력한다. Watch 입력은 페어링된 iPhone으로 전달한다.':'iPhone에서 기분·스트레스·오후 카페인을 선택해 저장한다.\nWatch는 페어링된 iPhone으로 전달한다.',
'목표 기상시각에서 목표 수면시간을 빼 취침 목표를 계산한다. 일정은 사용자가 입력하며 주간 최적화는 제공하지 않는다.':'기상 목표 - 수면 목표 = 취침 목표.\n수동 일정은 계산에 자동 반영하지 않는다.',
'홈':'오늘','분석':'질문','상담 요약':'요약',
'• 수면시간·단계\n\n• 데이터 출처\n\n• 체크인 진입\n\n• 취침 목표':'• 수면시간·단계\n\n• 데이터 출처\n\n• 최근 7일 평균\n\n• 목표 달성률',
'• 로컬 규칙 답변\n\n• 날짜·출처 근거\n\n• 같은 날짜 비교\n\n• 데이터 부족 안내':'• 로컬 규칙 답변\n\n• 날짜·출처 근거\n\n• 조건별 최소 2일\n\n• 샘플 비교 제외',
'HealthKit 실제 기록 또는 샘플 표시, 최근 수면 요약과 취침 목표를 한 화면에서 확인한다. 화면의 수치는 설명을 위한 예시다.':'HealthKit 또는 샘플 출처, 최근 7일 평균과 단계, 설정한 목표 대비 비율을 확인한다. 화면 수치는 예시다.',
'체크인 → 기록 입력\n취침 목표 → 계획 화면\n최근 수면 → 요약 화면':'탭 메뉴로 체크인·계획·요약 이동\n건강 연결 버튼으로 수면 조회\n홈 카드의 탭 이동은 미제공',
'• 최근 평균과 취침 목표를 이해하는가?':'• 최근 평균과 목표 달성률을 이해하는가?',
'WatchConnectivity userInfo로 페어링된 iPhone에 체크인을 전달한다.':'UUID를 담아 WatchConnectivity로 전송을 예약한다. iPhone 목록에서 실제 도착을 확인한다.'
}
def replace_shape_text(root):
    for shape in root.xpath('//p:sp',namespaces=ns):
        texts=shape.xpath('.//a:p',namespaces=ns)
        value='\n'.join(''.join(p.xpath('.//a:t/text()',namespaces=ns)) for p in texts)
        if value not in changes:continue
        replacement=changes[value].split('\n')
        body=shape.find('p:txBody',ns)
        if body is None:continue
        oldps=body.findall('a:p',ns)
        if not oldps:continue
        template=deepcopy(oldps[0])
        for old in oldps:body.remove(old)
        for line in replacement:
            para=deepcopy(template);runs=para.findall('a:r',ns)
            props=deepcopy(runs[0].find('a:rPr',ns)) if runs and runs[0].find('a:rPr',ns) is not None else None
            for child in list(para):
                if child.tag!=f'{{{ns["a"]}}}pPr':para.remove(child)
            run=etree.SubElement(para,f'{{{ns["a"]}}}r')
            if props is not None:run.append(props)
            etree.SubElement(run,f'{{{ns["a"]}}}t').text=line
            body.append(para)
    # Use a Korean font available in the renderer and on macOS.
    for face in root.xpath('//a:latin|//a:ea',namespaces=ns):face.set('typeface',FONT)
def update_task_table(tree):
    for tbl in tree.xpath('//a:tbl',namespaces=ns):
        rows=tbl.findall('a:tr',ns)
        if len(rows)!=5: continue
        values=[['ID','과업','성공 기준'],['T1·T2','수면 출처와 체크인','폰 저장 확인 · Watch 선택'],['T3','질문과 근거 확인','날짜·출처·부족 안내'],['T4','목표와 수동 일정','취침 목표 계산 · 일정 보관'],['T5','최근 7일 요약 PDF','생성 후 전송 없이 확인']]
        for row,data in zip(rows,values):
            for cell,text in zip(row.findall('a:tc',ns),data):
                texts=cell.xpath('.//a:t',namespaces=ns)
                if texts:
                    texts[0].text=text
                    for t in texts[1:]: t.text=''
source=ROOT/'02_Jammanbo_UIUX.pptx';out=ROOT/'output/pptx/02_Jammanbo_UIUX_v5.pptx'
with ZipFile(source) as z, ZipFile(out,'w',ZIP_DEFLATED) as w:
    for info in z.infolist():
        data=z.read(info.filename)
        if re.fullmatch(r'ppt/slides/slide\d+\.xml',info.filename):
            tree=etree.fromstring(data);replace_shape_text(tree);update_task_table(tree)
            data=etree.tostring(tree,xml_declaration=True,encoding='UTF-8',standalone=True)
        w.writestr(info,data)
(ROOT/'02_Jammanbo_UIUX.pptx').write_bytes(out.read_bytes())
print('Updated 3 DOCX sources and 2 synchronized PPTX files')
