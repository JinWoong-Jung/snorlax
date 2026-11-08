"""Synchronize submission sources; run with the Codex artifact runtime Python.

DOCX uses python-docx. The UI/UX deck is synchronized separately by sync_submission_deck.mjs.
PDF export and visual inspection are separate steps.
"""
from pathlib import Path
import re
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
    compact=True
    t=d.add_table(rows=1, cols=len(rows[0]));t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.autofit=False
    n=len(rows[0]);widths=({2:[4.2,13.3],3:[3.2,7.5,6.8],4:[2.0,6.5,3.3,5.7],7:[1.6,1.7,2.0,1.4,1.5,2.8,6.5]}.get(n,[17.5/n]*n))
    if rows[0][0] == '제안 구성요소': widths=[4.0,7.0,6.5]
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

# Markdown is the reviewable text source; keep requirement IDs stable.
req=ROOT/'docs/requirements/SSRD.md'
from_markdown(req, ROOT/'01_Jammanbo_SSRD.docx', '잠만보 요구사항 명세서',
    ('4 기능 요구사항: 기록과 질문','5 기능 요구사항: 계획과 공유','7 인터페이스와 데이터 규칙','9 수용 검증 시나리오','11 LLM API 연동 요구사항 설계안'))
arch=ROOT/'docs/architecture/Application_Structure.md'
sections=[plain(x[3:]) for x in arch.read_text().splitlines() if x.startswith('## ')][1:]
from_markdown(arch, ROOT/'03_Jammanbo_SSAD.docx','잠만보 소프트웨어 구조와 애플리케이션 설계',sections)
print('Updated 01 SSRD and 03 SSAD. UI/UX deck and PDF export are separate steps.')
