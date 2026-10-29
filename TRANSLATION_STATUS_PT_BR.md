# Tradução do Breedbase para português brasileiro

Atualizado em 29/10/2026.

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

### Backend Perl (`lib/`) — pendências adicionais identificadas

A tradução das mensagens do backend foi organizada nas seguintes etapas:

1. **Validação de arquivos importados (concluída em 29/10/2026):** mensagens de erro e aviso dos plugins `ParseUpload` de ensaios, acessos, lotes de sementes, vetores, transformação, locais, pedigree/cruzamentos, fenótipos e genótipos (88 arquivos), além do leitor genérico `CXGN::File::Parse`, cujas mensagens são herdadas por todos os plugins que o utilizam. O mapeamento por expressões regulares em `LocationsGeneric.pm` passou a apenas repassar as mensagens, que já chegam em português. Nomes de colunas, valores aceitos, referências de células e tokens de formato (por exemplo, `#CHROM`, `Xvalue`, tipos de cruzamento) continuam literais dentro das mensagens. O validador BrAPI `CXGN::Phenotypes::ParseUpload::Plugin::Observations` permanece em inglês, porque suas mensagens fazem parte das respostas da API. Erros internos (`die` não exibidos ao usuário) e registros de log também permanecem em inglês.
2. **Controladores (concluída em 29/10/2026):** mensagens de erro, sucesso e aviso das respostas JSON, textos de páginas de erro, rótulos HTML gerados pelo servidor e e-mails enviados aos usuários em 127 arquivos de `lib/SGN/Controller` (exceto os controladores BrAPI). Permanecem em inglês: status e valores comparados pelo JavaScript (por exemplo, os status de tarefas do solGS e a marca `curator warning`), dados gravados no banco (descrições de transações, notas de modificação), cabeçalhos de arquivos baixados, termos de ontologia e nomes de imagens/bandas, comandos R, e-mails internos para a equipe, os e-mails de `Report.pm` (o envio por `CXGN::Contact::send_email` não codifica caracteres não ASCII) e registros de log. Nos erros que incluem `$@` de módulos internos, apenas o prefixo foi traduzido; o texto do módulo será tratado na fase 3.
3. **Revisão complementar de `lib` (concluída em 29/10/2026):** as 20 pendências inicialmente confirmadas foram traduzidas. A busca ampliada resultou em alterações em **76 módulos**, incluindo páginas de erro, controladores de busca e publicação, formulários legados, BLAST/GWAS, materiais e lotes de sementes, downloads de ensaios, validação de etiquetas, painéis de imagens de drones, visualizações de ensaios, árvores de cruzamentos ODK e notificações do solGS. Os módulos `StoreVCFGenotypes`, `AddPedigrees` e `StorePhenotypes` já tinham as mensagens principais em português e não foram retraduzidos nesta etapa.

**Nova auditoria de 29/10/2026:** foram confirmados mais **21 trechos em 17 arquivos**, registrados em `support_data/translation/pendencias_adicionais_confirmadas.tsv`. Cinco arquivos pertencem à aplicação/formulário: `Biosource.pm`, `Qtl.pm`, `ITAG.pm`, `Bulk/Display.pm` e `forms/primer3/formfu_create.yaml`. Os outros 12 são scripts legados em `cgi-bin`; as mensagens existem no código, mas o uso das rotas CGI na instalação precisa ser verificado. A lista é um conjunto de achados confirmados, não uma contagem exaustiva de todas as pendências. Esta auditoria apenas registrou os trechos e não alterou código.

A busca incluiu mensagens que começam por variáveis, textos em minúsculas e formulários externos aos templates Mason. A auditoria do Mason continua com 774 candidatos em 181 arquivos, sem diferença em relação ao relatório anterior; esses candidatos não equivalem a 774 pendências, pois incluem nomes técnicos, dados de integração e falsos positivos. A existência das novas mensagens demonstra que as etapas anteriores não constituem uma comprovação de cobertura integral da tradução.

O inventário dos 76 módulos está em `support_data/translation/revisao_lib_pt_br.tsv`. O relatório inicial `support_data/translation/pendencias_lib_confirmadas.tsv` foi preservado como referência, com as 20 entradas marcadas como traduzidas. A revisão preservou parâmetros, chaves JSON, valores de API, termos de ontologia, dados de usuários, cabeçalhos de arquivos de integração e status de tarefas. Comentários, logs, diagnósticos internos e respostas BrAPI continuam em inglês de propósito; isso inclui o registro de clientes do aplicativo BrAPI, que é uma integração externa, e mensagens técnicas/administrativas de instalação e configuração.

Nos formulários de busca, os botões exibem `Buscar`, mantendo `value="Search"`; a opção `Qualquer um` mantém explicitamente `value="Any"`, e os modos de busca mantêm os valores originais em inglês. A comparação com a versão original confirmou a preservação das variáveis interpoladas e que as alterações se limitam aos textos revisados, às declarações `use utf8;`, à separação de rótulos e valores e aos ajustes de codificação descritos a seguir.

As notificações do solGS passaram a codificar o assunto como cabeçalho MIME e o corpo em UTF-8 com quoted-printable. No BLAST, o cabeçalho HTML traduzido é gravado em UTF-8 e lido como texto Unicode; a saída tabular permanece igual. Os títulos de gráficos R gerados pelo Perl usam escapes Unicode para manter o comando enviado ao cluster em ASCII.

**Verificação desta etapa:** `prove -v t/unit/localization_lib.t` passou com **29 verificações**, cobrindo validação de nomes/extensões de imagens, erros de formulários, valores dos botões e seletores, comportamento de caixas de seleção, rejeição de arquivos de tipo incorreto, preservação de acentos e links nas notificações e preservação dos dados tabulares e descrições do BLAST. O teste compila e executa os métodos envolvidos em isolamento, com substitutos locais para dependências; nenhum e-mail foi enviado. Oito arquivos de testes existentes tiveram suas asserções atualizadas. `git diff --check` passou para as alterações em `lib` e `t`.

A suíte completa com banco de dados e Selenium e a compilação integral dos módulos Catalyst não foram executadas: o carregamento de Moose/Catalyst neste ambiente falha pela ausência de `Data::OptList`. Essa limitação não foi contornada com alterações nas dependências da aplicação.

Alguns testes legados e de Selenium ainda verificam rótulos em inglês de páginas Mason traduzidas em etapas anteriores e precisarão de ajuste: `t/legacy/integration/insilicopcr/index.t`, `t/unit_mech/Controller/personalized_homepage.t`, `t/selenium2/01_list/accession_list_validation_fail.t`, `t/selenium2/search/locus.t`, `t/selenium2/search/people.t`, `t/unit_mech/Controller/Organism/Search.t`, `t/legacy/integration/gem.t`, `t/legacy/integration/phenome/solqtl.t`, `t/legacy/integration/solgs/solgs.t`, `t/legacy/integration/bulk*.t`, `t/legacy/SGN/Controller/Organism.t` e os testes de logout em `t/legacy/integration/solpeople.t` e `t/legacy/integration/solpeople/login.t`. Na revisão inicial, a pilha de dependências Perl não carregava no ambiente local; os módulos completos e as suítes que dependem da aplicação não foram executados. A verificação foi feita por comparação de tokens com o `master`, que confirma que apenas o conteúdo das strings mudou (além da inclusão de `use utf8;`).

### Scripts R (`R/`) — concluído

A revisão de 29/10/2026 cobriu os **50 scripts** da pasta `R` e os dois READMEs do pipeline de banana. Foram alterados 31 scripts no total. O inventário por arquivo está em `support_data/translation/revisao_r_pt_br.tsv`.

Foram traduzidos os textos próprios voltados ao usuário: erros e avisos de validação, mensagens de herdabilidade e controle de qualidade, descrições de qualidade na análise espacial, nomes descritivos de delineamentos na estratificação de ambientes, relatórios de PCA/agrupamento/predição genômica, tabelas de ANOVA, mensagens do MADII, anotações e legendas dos gráficos e a interface dos dois painéis Shiny. Também foram localizados os rótulos acrescentados pelos pacotes de gráficos NIRS e agrupamento, e a apresentação dos relatórios de filtragem e ANOVA produzidos por `genoDataFilter` e `phenoAnalysis`.

Os cálculos, fórmulas, dados originais, nomes de acessos e características, cabeçalhos de arquivos usados como contratos, chaves JSON, parâmetros e valores de opções foram preservados. Nos painéis Shiny, as opções enviam os valores originais, as abas têm IDs explícitos e a tradução de cabeçalhos/atividades acontece em cópias para apresentação; os filtros e as exportações CSV continuam usando os dados originais. Os auxiliares de relatórios ficam nos próprios scripts porque o controlador copia cada script individualmente para executar no cluster.

**Mantido em inglês de propósito:** comentários e registros de depuração, mensagens administrativas do instalador de pacotes, e-mails internos do pipeline, nomes científicos, nomes de métodos recebidos do servidor, códigos como `YES`/`NO`, termos de fórmulas e resumos técnicos brutos de modelos. Diagnósticos originais de exceções de terceiros e mensagens desconhecidas de outras versões dos pacotes são preservados, evitando alterar dados ou ocultar a informação técnica. Relatórios que já estavam no cache antes da tradução permanecem como foram gerados; os novos resultados usam os textos traduzidos.

**Verificação:** 47 scripts passaram pelo parser do R. Os três arquivos restantes já tinham erros de sintaxe em `HEAD` e foram mantidos intactos: `R/BLUP_modelling.r` (linha 28) e as duas cópias de `banana_pipeline_analysisScript.R` (linha 665). A comparação das chamadas estatísticas com `HEAD` confirmou a preservação dos modelos e cálculos nos scripts válidos. O teste de regressão confere os valores de entrada e IDs das abas Shiny, os filtros, a preservação dos CSVs e dos dados, nomes de usuário que contêm trechos em inglês e a formatação dos relatórios. Foram exercitados relatórios reais de `phenoAnalysis` e `genoDataFilter`, tabelas HTML/texto de ANOVA e gráficos do pacote `waves`, sem alteração dos resultados numéricos. Os gráficos NIRS, do cotovelo e de ganho genético foram gerados com dados sintéticos e inspecionados visualmente; o HTML dos dois painéis Shiny também foi renderizado. A execução integral com banco de dados e dados reais de produção não foi realizada.

Para repetir as verificações, na raiz do repositório:

```bash
Rscript t/r/localization_pt_br.R
```

As verificações com pacotes externos usam as bibliotecas R ativas e informam quando um pacote opcional não está disponível. Nesta revisão, `phenoAnalysis` e `genoDataFilter` foram carregados do diretório local de pacotes da instalação Breedbase, após as bibliotecas padrão, para evitar sobrepor dependências compiladas para outra versão do R.

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
