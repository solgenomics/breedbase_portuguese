# Tradução do Breedbase para português brasileiro

Atualizado em 28/10/2026.

## Situação

A revisão de 28/10/2026 concluiu a passagem pelos textos de interface do diretório `mason` e do JavaScript próprio da aplicação (`js/source/entries`, `js/source/modules` e os diretórios próprios em `js/source/legacy`: `CXGN`, `SGN`, `solGS`, `brapi`, `tools`, `d3/graphers`, entre outros), incluindo os blocos `<script>` dos templates.

A auditoria estática (`bin/audit_mason_translation.py`) aponta 774 trechos candidatos em 181 arquivos. Na revisão, esses trechos correspondem a conteúdo mantido em inglês de propósito: nomes de colunas dos arquivos de importação/exportação, citações e títulos de publicações, nomes de instituições, exemplos JSON/VCF e palavras portuguesas que a heurística confunde com inglês (por exemplo, "Data"). A lista pode ser regenerada com o comando ao final deste documento.

### Correções de regressões da tradução anterior

A revisão encontrou e corrigiu pontos em que a tradução automática alterava código ou contratos de dados:

- cabeçalhos de planilhas de exemplo traduzidos ou deformados (`row` → "Reme", `maleDbId` → "México", `timestamp` → "Timetamp"), que levariam o usuário a montar arquivos rejeitados pelo servidor;
- nomes de parâmetros enviados ao servidor (`categories[]`, `querytypes[]`, `data[i][]`, `images`, `captcha`, `studyType: "Trial"`), chaves de objetos (`form["name"]`, `"error"`/`"message"`), opções de bibliotecas (`allowInput` do flatpickr) e valores comparados (`"matching"`, `"Ungrouped"`, `"Population Structure"`, `"iqr"`, `"bet"`);
- classes CSS/SVG usadas por seletores (`x axis`, `PC1 axis`, `textPath`) e marcações HTML quebradas dentro de strings JavaScript (links Editar/Excluir/Remover sem `)` ou com `&gt;` no lugar de `>`);
- códigos ISO de países em `mason/breeders_toolbox/location_map.mas` ("AND E Andorra", "CAN PODE O Canadá", "DEU DEEU Alemanha" etc.);
- valores permitidos e termos de ontologia traduzidos (`open, polycross`, `light intensity|EXPERIMENT_TREATMENT:00000XX`);
- chaves YAML dos blocos `data_items` em `mason/secretom`;
- traduções incorretas como "PRIMER ESQUECER" (LEFT PRIMER), "Secretário" (Record), "Massa" (Folder), "suas escutas" (your lists), "Entrando" (in., polegadas) e "Use o Secretário Tary" (SecreTary).

### Mantido em inglês de propósito

Bibliotecas de terceiros, comentários de desenvolvimento, mensagens de `console.*`, identificadores, caminhos, parâmetros e valores de API, cabeçalhos de arquivos usados como contratos de importação/exportação e seus valores permitidos, termos de ontologia (por exemplo, `...|SGNSTAT:0000034`), nomes científicos, citações, nomes de produtos (Field Book, BrAPI, SecreTary, Primer3, GBrowse) e strings comparadas com respostas do servidor. Quando um rótulo visível também é enviado como valor, o rótulo foi traduzido e o valor original foi mantido em `value=`; nos casos em que isso não era seguro (por exemplo, `CGI::submit('Search','Search')` em `mason/gbrowse/search_box.mas` e os formatos de característica em `mason/chado/cvtermprops.mas`), o texto ficou em inglês.

### Backend Perl (`lib/`)

A tradução das mensagens do backend está sendo feita em fases:

1. **Validação de arquivos importados (concluída em 29/10/2026):** mensagens de erro e aviso dos plugins `ParseUpload` de ensaios, acessos, lotes de sementes, vetores, transformação, locais, pedigree/cruzamentos, fenótipos e genótipos (88 arquivos), além do leitor genérico `CXGN::File::Parse`, cujas mensagens são herdadas por todos os plugins que o utilizam. O mapeamento por expressões regulares em `LocationsGeneric.pm` passou a apenas repassar as mensagens, que já chegam em português. Nomes de colunas, valores aceitos, referências de células e tokens de formato (por exemplo, `#CHROM`, `Xvalue`, tipos de cruzamento) continuam literais dentro das mensagens. O validador BrAPI `CXGN::Phenotypes::ParseUpload::Plugin::Observations` permanece em inglês, porque suas mensagens fazem parte das respostas da API. Erros internos (`die` não exibidos ao usuário) e registros de log também permanecem em inglês.
2. **Controladores (concluída em 29/10/2026):** mensagens de erro, sucesso e aviso das respostas JSON, textos de páginas de erro, rótulos HTML gerados pelo servidor e e-mails enviados aos usuários em 127 arquivos de `lib/SGN/Controller` (exceto os controladores BrAPI). Permanecem em inglês: status e valores comparados pelo JavaScript (por exemplo, os status de tarefas do solGS e a marca `curator warning`), dados gravados no banco (descrições de transações, notas de modificação), cabeçalhos de arquivos baixados, termos de ontologia e nomes de imagens/bandas, comandos R, e-mails internos para a equipe, os e-mails de `Report.pm` (o envio por `CXGN::Contact::send_email` não codifica caracteres não ASCII) e registros de log. Nos erros que incluem `$@` de módulos internos, apenas o prefixo foi traduzido; o texto do módulo será tratado na fase 3.
3. **Demais módulos de `lib/CXGN` e `lib/SGN`:** pendente (inclui mensagens equivalentes às dos parsers em `CXGN::Genotype::StoreVCFGenotypes` e `CXGN::Pedigree::AddPedigrees`).

Os testes em `t/` que verificam o texto dessas mensagens foram atualizados nas duas fases (cerca de 30 arquivos em `t/unit_fixture`, `t/unit_mech`, `t/selenium2` e `t/legacy`). Asserções sobre mensagens produzidas por módulos ainda não traduzidos (por exemplo, `CXGN::Phenotypes::StorePhenotypes`, `CXGN::Genotype::StoreVCFGenotypes`, `CXGN::BrAPI::FileRequest`) foram mantidas em inglês.

Alguns testes legados e de Selenium ainda verificam rótulos em inglês de páginas Mason traduzidas em etapas anteriores e precisarão de ajuste: `t/legacy/integration/insilicopcr/index.t`, `t/unit_mech/Controller/personalized_homepage.t`, `t/selenium2/01_list/accession_list_validation_fail.t`, `t/selenium2/search/locus.t`, `t/selenium2/search/people.t`, `t/unit_mech/Controller/Organism/Search.t`, `t/legacy/integration/gem.t`, `t/legacy/integration/phenome/solqtl.t`, `t/legacy/integration/solgs/solgs.t`, `t/legacy/integration/bulk*.t`, `t/legacy/SGN/Controller/Organism.t` e os testes de logout em `t/legacy/integration/solpeople.t` e `t/legacy/integration/solpeople/login.t`. As dependências Perl (Catalyst, Moose, DBIx::Class) não estão instaladas no ambiente local; por isso, os módulos não foram compilados nem os testes executados. A verificação foi feita por comparação de tokens com o `master`, que confirma que apenas o conteúdo das strings mudou (além da inclusão de `use utf8;`).

## Compatibilidade

- As abas de importação de acessos usam IDs estáveis, em vez dos títulos traduzidos.
- O designer de etiquetas traduz os rótulos mantendo os valores das opções, os nomes dos campos e as chaves de modelos salvos.
- As opções de análise de agrupamento, correlação, parentesco e PCA exibem `Genótipo`/`Fenótipo`, mantendo `Genotype`/`Phenotype` como valores enviados ao servidor.
- A comparação dos scripts conferiu a preservação de rotas, seletores, atributos funcionais HTML e valores `analysis_type`.

## Verificação

A compilação de produção com Webpack foi executada. O teste de regressão de localização verifica os rótulos das opções, a preservação dos valores internos e a reaplicação da tradução sem alterar dados do usuário:

```bash
node js/test/localization.test.cjs
```

A suíte JavaScript existente apresentou 5 verificações aprovadas e 1 falha no teste de boxplot (`expected calls made`, acompanhada de erro de `listener` na camada jsdom). A mesma falha foi reproduzida numa cópia isolada do commit original, usando as mesmas dependências. O teste do assistente de busca foi executado separadamente.

A comparação dos blocos `<script>` encontrou quatro exceções lexicais já presentes na versão original: código legado com escape de Perl em `mason/cview/index.mas` e `mason/image/print_images.mas`, um bloco Perl dentro do script de `mason/image/plot_images.mas` e uma referência a script em comentário em `mason/tools/vectorviewer.mas`. Esses casos não equivalem a quatro novos erros de JavaScript.

Na revisão de 28/10/2026, todos os arquivos JavaScript alterados passaram em `node --check`, o teste de localização passou e a compilação Webpack de produção terminou sem erros. Os blocos `<script>` dos templates Mason alterados (com as expressões `<% %>` substituídas por um valor fixo) foram analisados com `vm.Script` do Node: nenhum bloco válido no `master` deixou de ser válido. As linhas Perl (`%`, `<%init>`, `<%perl>`) foram comparadas por token com o `master` e só apresentam alterações em literais de texto. Essa verificação de sintaxe não detecta HTML quebrado dentro de strings; esses casos foram procurados por comparação com o `master`.

A compilação completa dos componentes Mason e a inspeção visual no navegador não foram realizadas: o módulo `HTML::Mason::Interp` não está instalado no ambiente local e não havia uma instância Breedbase em execução.

## Repetir a auditoria do Mason

Na raiz do repositório:

```bash
python3 bin/audit_mason_translation.py --report support_data/translation/pendencias_mason.tsv
```

O script é somente de leitura em relação aos templates. Ele usa indícios de idioma para apontar textos visíveis e argumentos de componentes, ignorando scripts, estilos, exemplos de código e blocos Perl. A revisão do resultado é necessária; resultado vazio também não comprovaria cobertura de conteúdo dinâmico.
