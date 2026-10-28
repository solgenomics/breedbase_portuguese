# Tradução do Breedbase para português brasileiro

Atualizado em 28/10/2026.

## Situação

O diretório `mason` **ainda não está integralmente traduzido**. A auditoria estática examinou 1.130 arquivos e identificou 3.854 trechos candidatos à revisão em 533 arquivos. Esse número inclui possíveis falsos positivos e termos técnicos; não representa uma contagem definitiva de traduções faltantes.

A lista completa, com arquivo, linha e texto, está em [pendencias_mason.tsv](support_data/translation/pendencias_mason.tsv). Há pendências reais, por exemplo em `mason/about/audit.mas`, em páginas de ajuda, ferramentas e conteúdo histórico de genômica.

A revisão dos textos de interface do JavaScript próprio da aplicação abrangeu 136 arquivos em `js/source` e 560 blocos `<script>` nos templates. As alterações atuais em relação ao commit original abrangem 109 arquivos JavaScript e 184 arquivos Mason. Foram traduzidos avisos, confirmações, erros, rótulos, títulos, botões, descrições e textos gerados pelos scripts.

Bibliotecas de terceiros, comentários de desenvolvimento, identificadores, caminhos, valores de API, cabeçalhos de arquivos usados como contratos de importação/exportação e nomes científicos/termos de ontologia mantêm seus valores originais. Mensagens retornadas pelo backend e nomes fornecidos pelo usuário exigem revisão separada. Esses limites não permitem prometer que toda tela renderizada estará livre de inglês.

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

A compilação completa dos componentes Mason e a inspeção visual no navegador não foram realizadas: o módulo `HTML::Mason::Interp` não está instalado no ambiente local e não havia uma instância Breedbase em execução.

## Repetir a auditoria do Mason

Na raiz do repositório:

```bash
python3 bin/audit_mason_translation.py --report support_data/translation/pendencias_mason.tsv
```

O script é somente de leitura em relação aos templates. Ele usa indícios de idioma para apontar textos visíveis e argumentos de componentes, ignorando scripts, estilos, exemplos de código e blocos Perl. A revisão do resultado é necessária; resultado vazio também não comprovaria cobertura de conteúdo dinâmico.
