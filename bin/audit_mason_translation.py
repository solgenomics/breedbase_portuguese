#!/usr/bin/env python3
"""Find likely English UI text in Mason templates without modifying sources.

This is a review aid, not a proof of complete translation. It excludes scripts,
styles, code examples and Perl blocks; review generated/server text separately.
"""
import argparse
import csv
import html
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
ENGLISH = set('''please select upload download add edit delete save cancel search view
create submit close next previous name description trial trials accession accessions
trait traits dataset datasets location locations breeding program programs year years
phenotype phenotypes genotype genotypes marker markers sequence sequences primer
primers data file files list lists warning working loading processing result results
value values sample samples field fields plot plots plant plants cross crosses parent
parents pedigree pedigrees source filter selected found missing valid invalid required
check overwrite stored enter click only the this that these those you your which
will should must cannot without with from of for and not are was were have has can
more each between number count total choose reset update confirm none all public
private attributes start stop button export import compare image images display
show statistics available maximum minimum login username password account user users
register email address order seedlot seedlots treatment treatments type table help
welcome contact information details successful successfully failed failure unknown
error title documentation about overview release annotation browse organism organisms
chromosome chromosomes database databases content containing contains use using
first last back return continue print page pages report reports format formats'''.split())
PORTUGUESE = set('''selecione informe nenhum nenhuma todos todas dados ensaio ensaios
acesso acessos arquivo arquivos erro ocorreu baixar enviar salvar excluir adicionar
buscar busca visualizar visualizar programa programas melhoramento com para uma
este esta estes estas pelo pela clique nome nomes tipo tipos local locais lista
listas por foi foram seu sua seus suas escolha entre apenas propriedades alterar
voltar ajuda novo nova plantas parcelas sobre outro outros total'''.split())


def blank(match):
    return re.sub(r'[^\n]', ' ', match.group(0))


def likely_english(text):
    text = html.unescape(text)
    words = re.findall(r'[A-Za-zÀ-ÿ]+', text.lower())
    english = sum(word in ENGLISH for word in words)
    portuguese = sum(word in PORTUGUESE for word in words)
    # Technical expressions and already translated prose require human judgment.
    return english > 0 and (portuguese == 0 or english > portuguese + 1)


def candidates():
    paths = sorted(path for path in (ROOT / 'mason').rglob('*') if path.is_file())
    rows = []
    for path in paths:
        try:
            raw = path.read_text(encoding='utf-8')
        except UnicodeError:
            continue
        masked = re.sub(r'<!--.*?-->', blank, raw, flags=re.S)
        masked = re.sub(r'<(script|style|code|pre)\b[^>]*>.*?</\1\s*>', blank,
                        masked, flags=re.S | re.I)
        masked = re.sub(r'<%(args|init|perl|once|def|method|doc|flags|attr|shared|cleanup|filter)\b[^>]*>.*?</%\1\s*>',
                        blank, masked, flags=re.S | re.I)
        masked = re.sub(r'^\s*%[^\n]*', blank, masked, flags=re.M)
        masked = re.sub(r'<%.*?%>|<&.*?&>', blank, masked, flags=re.S)
        found = []
        for match in re.finditer(r'(?<=>)([^<>]+)(?=<|$)', masked):
            found.append((match.start(1), match.group(1)))
        for match in re.finditer(r'\b(?:title|placeholder|alt|aria-label)\s*=\s*(["\x27])([^"\x27<>]*)\1', masked):
            found.append((match.start(2), match.group(2)))
        # Labels passed as Mason component arguments do not appear as text nodes.
        for match in re.finditer(r'\b(?:title|subtitle|info_section_title|info_section_subtitle|empty_message|label)\s*=>\s*(["\x27])([^"\x27]*)\1', raw):
            found.append((match.start(2), match.group(2)))
        seen = set()
        for offset, text in sorted(found):
            text = ' '.join(html.unescape(text).split())
            if not text or re.search(r'[{}=$]|^https?://', text) or not likely_english(text):
                continue
            line = raw.count('\n', 0, offset) + 1
            key = line, text
            if key in seen:
                continue
            seen.add(key)
            rows.append((str(path.relative_to(ROOT)), line, text))
    return len(paths), rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report', type=Path, help='Write review candidates as UTF-8 TSV')
    args = parser.parse_args()
    count, rows = candidates()
    if args.report:
        with args.report.open('w', encoding='utf-8', newline='') as stream:
            writer = csv.writer(stream, delimiter='\t', lineterminator='\n')
            writer.writerow(['arquivo', 'linha', 'texto_para_revisar'])
            writer.writerows(rows)
    print(f'{count} arquivos Mason examinados; {len(rows)} trechos candidatos em '
          f'{len(set(row[0] for row in rows))} arquivos. Requer revisão humana.')
    if not args.report:
        for path, line, text in rows:
            print(f'{path}:{line}: {text}')


if __name__ == '__main__':
    main()
