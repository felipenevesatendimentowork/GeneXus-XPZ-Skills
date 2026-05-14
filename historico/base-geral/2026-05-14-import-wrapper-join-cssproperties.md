# Evidencia: import real, pos-processamento do wrapper e CssProperties.json

## Contexto

Em 2026-05-14, uma importacao real na KB `C:\GxModels\FabricaBrasil18` usou o wrapper
`scripts/Invoke-GeneXusXpzImport.ps1` para importar o pacote
`ImportProdAutazMirim_41d00b88-b814-4d10-8894-8c1f5ec2edba_20260514_01.import_file.xml`.

O pacote continha exatamente 3 objetos:

- `SDT:sdtMSPROD`
- `Procedure:procCrudMsprod`
- `Procedure:procListaTextoParaListaSdtConformeTipoGenerico`

Artefatos da rodada ficaram em:
`Temp/xpz-msbuild-import-export/gx-import-real-e3cc30bdb2d549469277f0e3132b404b/`.

## Importacao efetiva confirmada

O `msbuild.stdout.log` confirmou sucesso antes da falha do wrapper:

```text
Importando Structured Data Type 'sdtMSPROD' ...
  Bem sucedido
Importando Procedure 'procCrudMsprod' ...
O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado.
  Bem sucedido
Importando Procedure 'procListaTextoParaListaSdtConformeTipoGenerico' ...
  Bem sucedido
> Import Task Sucesso
__IMPORTED_ITEM__=Procedure:procCrudMsprod
__IMPORTED_ITEM__=Procedure:procListaTextoParaListaSdtConformeTipoGenerico
__IMPORTED_ITEM__=SDT:sdtMSPROD
```

O `msbuild.stderr.log` existia, mas estava vazio (`0` bytes).

## Caso 1: `Exception calling "Join"` no pos-processamento

### Achado

O wrapper falhou depois da importacao real, durante o pos-processamento de stdout/stderr:

```text
Exception calling "Join" with "2" argument(s): "Value cannot be null. (Parameter 'values')"
```

Ponto exato informado na investigacao:

- arquivo: `scripts/Invoke-GeneXusXpzImport.ps1`
- linha: `728`
- bloco: `try` iniciado na linha `548`, com queda ate o `catch` global da linha `801`

Linha problematica:

```powershell
$stdErrNoise = [string]::Join("`n", ([regex]::Matches($stdErrText, '(?m)context \[anonymous\] \d+:\d+ attribute component isn''t defined') | ForEach-Object { $_.Value }))
```

### Causa mecanica

Quando `msbuild.stderr.log` esta vazio, `Read-TextFileSafe` retorna `""`.
`[regex]::Matches("", ...)` retorna uma colecao vazia.
O pipeline `| ForEach-Object { $_.Value }` nao emite itens e, dentro dos parenteses,
chega como `$null` para `[string]::Join(...)`.

Assim, `Join` recebe `values=$null` e dispara `ArgumentNullException`.

### Impacto

Funcionalmente, a importacao ja tinha sido concluida com sucesso pelo MSBuild.
O impacto e diagnostico: o `catch` global emitiu `exitCode=90`, `status="falha operacional"`,
zerou `importedItems` e nao propagou caminhos de `msbuild.stdout.log`, `msbuild.stderr.log`
e `import-real.msbuild`, embora esses artefatos existissem em disco.

Isso viola a expectativa operacional da skill `xpz-msbuild-import-export`: se o
pos-processamento falhar depois do MSBuild, o diagnostico parcial deve preservar a
evidencia ja coletada.

### Direcao de correcao

Hotfix minimo:

```powershell
$stdErrNoise = [string]::Join("`n", @(
    [regex]::Matches($stdErrText, '(?m)context \[anonymous\] \d+:\d+ attribute component isn''t defined') |
        ForEach-Object { $_.Value }
))
```

Correcao mais robusta:

- envolver o bloco de pos-processamento pos-MSBuild em `try/catch` interno;
- preservar `MsBuildFilePath`, `StdOutPath`, `StdErrPath` e exit code real do MSBuild;
- extrair `importedItems` diretamente do stdout bruto quando possivel;
- emitir campo como `postProcessingFailed=true` sem transformar importacao bem-sucedida em falha operacional opaca.

## Caso 2: acesso negado a `CssProperties.json`

### Achado

Durante a importacao de `procCrudMsprod`, o stdout registrou:

```text
O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado.
```

Sequencia relevante:

```text
Importando Procedure 'procCrudMsprod' ...
O acesso ao caminho 'C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json' foi negado.
  Bem sucedido
```

A mensagem apareceu apenas em stdout. O stderr estava vazio.

### Evidencia de ambiente

O arquivo existe:

- caminho: `C:\Program Files (x86)\GeneXus\GeneXus18\CssProperties.json`
- tamanho: `697.514` bytes
- `LastWriteTime`: `2025-11-28 21:16:38`
- `IsReadOnly`: `False`
- atributos: `Archive`

A negacao de acesso provavelmente vem da ACL do diretorio pai em `Program Files (x86)`,
nao do bit read-only do arquivo.

### Impacto

Baixo para a importacao observada:

- o objeto em curso foi marcado como `Bem sucedido`;
- o objeto anterior tambem foi importado com sucesso;
- o objeto posterior tambem foi importado com sucesso;
- a task terminou com `Import Task Sucesso`.

### Classificacao operacional

Tratar como ruido informativo de ambiente GeneXus sem elevacao, enquanto aparecer com
`Bem sucedido` e sem erro em stderr. Nao elevar automaticamente MSBuild/GeneXus por
causa dessa mensagem.

Se a mensagem passar a bloquear import ou build, reclassificar como incidente operacional.
