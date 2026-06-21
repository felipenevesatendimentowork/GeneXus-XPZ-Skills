#requires -Version 7.4
<#
.SYNOPSIS
  Suporte (dot-source) para o check generico forwards_unknown_engine_param do inventario
  de wrappers locais (Test-XpzWrapperInventory.ps1).

.DESCRIPTION
  Verifica, por AST + Get-Command (sem executar o motor, sem KB), que todo parametro que
  um wrapper local REPASSA a um motor compartilhado ADVANCED de fato EXISTE no motor (nome
  canonico ou alias). Em motor advanced, repassar um parametro nao-declarado e erro de
  binding em runtime, invisivel ao parse/STRUCTURE_OK/GATE_OK e ao naming-contract.

  NAO e um self-test; nao emite sentinela. E dot-sourced por Test-XpzWrapperInventory.ps1.

  Discriminador de escopo (por VALOR, nao pelo nome da variavel-raiz):
    - site = `& $V ...` onde $V e atribuido (profundidade 1, mesmo escopo) de uma expressao
      `Join-Path <raiz> 'scripts\<Leaf>.ps1'` (formas literal/aninhada/multi-arg);
    - o discriminador opera no LITERAL 'scripts' da expressao Join-Path (AST), nao no caminho
      resolvido: `Join-Path $PSScriptRoot 'Rebuild.ps1'` resolve para .../scripts/Rebuild.ps1
      mas NAO tem o literal 'scripts' -> irmao local, fora de escopo;
    - leaf existente na pasta de motores do auditor (EnginesRoot) -> motor compartilhado;
    - leaf inexistente sob expressao com literal 'scripts' -> shared_engine_unresolved
      (sinal de desvio-de-wrapper; coerente com 8.a.ii do xpz-kb-parallel-setup);
    - alvo nao-resoluvel a uma expressao Join-Path literal (raiz dinamica, reatribuicao,
      multi-hop) -> pular o site (conservador; ver LIMITES).

  Deteccao advanced (sem executar): advanced sse os CommonParameters foram INJETADOS pelo
  runtime, i.e. presentes em Get-Command.Parameters mas AUSENTES do param() block declarado
  no AST do motor. Um SIMPLE que declare $Verbose literalmente nao e confundido com advanced.

  Comparacao de nomes: OrdinalIgnoreCase em todo o pipeline (binding e case-insensitive).

  LIMITES CONHECIDOS (pular o site + follow-up no 999-ideias-pendentes.md), nao auditados:
    - reatribuicao da variavel-raiz/intermediaria por expressao nao-rastreavel, multi-hop,
      basename composto por variavel, raiz totalmente dinamica;
    - invocacao direta sem variavel, Invoke-Expression, dot-source, pipeline, repasse
      posicional;
    - colisao de nome via `Join-Path $repoRoot 'scripts\<X>.ps1'` apontando para arquivo
      LOCAL cujo leaf coincide com motor canonico (fora do padrao dos moldes).
#>

Set-StrictMode -Version Latest

# CommonParameters que so coexistem em funcoes/scripts ADVANCED (injetados pelo runtime).
# Subconjunto estavel entre versoes do PowerShell 7.x usado como discriminador.
$script:XpzEngineParamCommonMarkers = @('Verbose', 'Debug', 'ErrorAction', 'WarningAction', 'OutBuffer')

function Get-XpzAstJoinPathLeaf {
    <#
      Recebe um Ast de expressao (lado direito de uma atribuicao ou o alvo do &).
      Se for (ou contiver) uma chamada Join-Path com um segmento literal 'scripts' e um
      leaf literal '<algo>.ps1', devolve [pscustomobject]@{ HasScriptsSegment; Leaf }.
      Caso nao seja Join-Path resoluvel a literais, devolve $null (alvo nao-resoluvel).
    #>
    param([System.Management.Automation.Language.Ast]$Ast)

    if ($null -eq $Ast) { return $null }

    # Desembrulhar Pipeline/CommandExpression ate o CommandAst do Join-Path, ou ParenExpression.
    $node = $Ast
    while ($true) {
        if ($node -is [System.Management.Automation.Language.PipelineAst]) {
            if (@($node.PipelineElements).Count -ne 1) { return $null }
            $node = $node.PipelineElements[0]; continue
        }
        if ($node -is [System.Management.Automation.Language.CommandExpressionAst]) { $node = $node.Expression; continue }
        if ($node -is [System.Management.Automation.Language.ParenExpressionAst]) { $node = $node.Pipeline; continue }
        break
    }

    if (-not ($node -is [System.Management.Automation.Language.CommandAst])) { return $null }

    $elements = @($node.CommandElements)
    if ($elements.Count -lt 1) { return $null }
    $cmdName = $elements[0]
    if (-not ($cmdName -is [System.Management.Automation.Language.StringConstantExpressionAst])) { return $null }
    if ($cmdName.Value -ine 'Join-Path') { return $null }

    # Coletar literais string desta chamada + de Join-Path aninhados nos argumentos.
    $literals = [System.Collections.Generic.List[string]]::new()
    for ($ei = 1; $ei -lt $elements.Count; $ei++) {
        $el = $elements[$ei]
        if ($el -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $literals.Add([string]$el.Value)
        } elseif ($el -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
            # string interpolada (ex.: "scripts\$leaf") -> nao-resoluvel a literal seguro
            return $null
        } elseif ($el -is [System.Management.Automation.Language.ParenExpressionAst] -or
                  $el -is [System.Management.Automation.Language.CommandExpressionAst] -or
                  $el -is [System.Management.Automation.Language.PipelineAst]) {
            $nested = Get-XpzAstJoinPathLeaf -Ast $el
            if ($null -ne $nested) {
                if ($nested.HasScriptsSegment) { return $nested }
                # aninhado resolveu mas sem 'scripts' -> agrega seus segmentos via leaf
                if ($nested.Leaf) { $literals.Add([string]$nested.Leaf) }
            }
        }
        # VariableExpressionAst (a raiz) e ignorado de proposito: o discriminador e por forma+leaf.
    }

    if ($literals.Count -eq 0) { return $null }

    # Quebrar cada literal em segmentos por \ ou /.
    $segments = [System.Collections.Generic.List[string]]::new()
    foreach ($lit in $literals) {
        foreach ($seg in @($lit -split '[\\/]+')) {
            if (-not [string]::IsNullOrWhiteSpace($seg)) { $segments.Add($seg) }
        }
    }

    $hasScripts = $false
    foreach ($seg in $segments) { if ($seg -ieq 'scripts') { $hasScripts = $true; break } }

    $leaf = $null
    for ($i = $segments.Count - 1; $i -ge 0; $i--) {
        if ($segments[$i] -imatch '\.ps1$') { $leaf = $segments[$i]; break }
    }

    if ($null -eq $leaf) { return $null }
    return [pscustomobject]@{ HasScriptsSegment = $hasScripts; Leaf = $leaf }
}

function Resolve-XpzEngineTarget {
    <#
      Resolve o alvo de um `& <target> ...` a um leaf de motor (profundidade 1, mesmo
      ScriptBlock raiz). Devolve [pscustomobject]@{ Kind; Leaf } onde Kind e:
        'shared'      -> Join-Path com literal 'scripts' + leaf (auditar; checar existencia)
        'local'       -> Join-Path sem literal 'scripts' (irmao local; fora de escopo)
        'unresolved'  -> nao-resoluvel a literal (pular)
    #>
    param(
        [System.Management.Automation.Language.Ast]$TargetAst,
        [System.Management.Automation.Language.Ast]$RootAst
    )

    # Caso 1: alvo e a propria expressao Join-Path (ex.: & (Join-Path ...) -P) — defensivo.
    $direct = Get-XpzAstJoinPathLeaf -Ast $TargetAst
    if ($null -ne $direct) {
        if ($direct.HasScriptsSegment) { return [pscustomobject]@{ Kind = 'shared'; Leaf = $direct.Leaf } }
        return [pscustomobject]@{ Kind = 'local'; Leaf = $direct.Leaf }
    }

    # Caso 2: alvo e uma variavel -> resolver a UNICA atribuicao literal no escopo.
    if (-not ($TargetAst -is [System.Management.Automation.Language.VariableExpressionAst])) {
        return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null }
    }
    $varName = $TargetAst.VariablePath.UserPath

    $assignments = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Left.VariablePath.UserPath -ieq $varName
            }, $true))

    if ($assignments.Count -ne 1) {
        # nenhuma, ou multiplas (reatribuicao) -> nao-rastreavel
        return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null }
    }

    $resolved = Get-XpzAstJoinPathLeaf -Ast $assignments[0].Right
    if ($null -eq $resolved) { return [pscustomobject]@{ Kind = 'unresolved'; Leaf = $null } }
    if ($resolved.HasScriptsSegment) { return [pscustomobject]@{ Kind = 'shared'; Leaf = $resolved.Leaf } }
    return [pscustomobject]@{ Kind = 'local'; Leaf = $resolved.Leaf }
}

function Get-XpzForwardedParamName {
    <#
      Extrai os NOMES de parametros repassados num site `& <target> <elements...>`.
      Explicitos via CommandParameterAst; splat via resolucao das chaves literais da
      variavel splatada. Redirecionamentos nao sao CommandElement -> ignorados.
    #>
    param(
        [System.Management.Automation.Language.CommandAst]$CommandAst,
        [System.Management.Automation.Language.Ast]$RootAst
    )

    $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $elements = @($CommandAst.CommandElements)
    # elemento 0 e o alvo (& $V); demais sao parametros/argumentos.
    for ($i = 1; $i -lt $elements.Count; $i++) {
        $el = $elements[$i]
        if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
            [void]$names.Add([string]$el.ParameterName)
        } elseif ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
            foreach ($k in (Get-XpzSplatLiteralKey -SplatVarName $el.VariablePath.UserPath -RootAst $RootAst)) {
                [void]$names.Add($k)
            }
        }
    }
    return @($names)
}

function Get-XpzSplatLiteralKey {
    <#
      Coleta as chaves literais de uma hashtable de splat (@var):
        - HashtableAst literal atribuido a $var;
        - membro  $var.Chave = ...
        - indice  $var['Chave'] = ...
        - metodo  $var.Add('Chave', ...)
      Chave nao-literal (dinamica) -> ignorada. Se $var sofrer mutacao por .Remove/.Clear
      ou reatribuicao por expressao nao-rastreavel, o chamador ja tera pulado o site; aqui
      apenas coletamos o que e literal.
    #>
    param([string]$SplatVarName, [System.Management.Automation.Language.Ast]$RootAst)

    $keys = [System.Collections.Generic.List[string]]::new()

    # (a) HashtableAst literal atribuido diretamente a $var.
    $assigns = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Left.VariablePath.UserPath -ieq $SplatVarName
            }, $true))
    foreach ($a in $assigns) {
        $right = $a.Right
        if ($right -is [System.Management.Automation.Language.CommandExpressionAst]) { $right = $right.Expression }
        if ($right -is [System.Management.Automation.Language.HashtableAst]) {
            foreach ($pair in $right.KeyValuePairs) {
                $keyAst = $pair.Item1
                if ($keyAst -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $keys.Add([string]$keyAst.Value)
                }
            }
        }
    }

    # (b) membro/indice: $var.Chave = ... ou $var['Chave'] = ...
    $memberAssigns = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $true))
    foreach ($a in $memberAssigns) {
        $left = $a.Left
        if ($left -is [System.Management.Automation.Language.MemberExpressionAst] -and
            $left.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $left.Expression.VariablePath.UserPath -ieq $SplatVarName -and
            $left.Member -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$left.Member.Value)
        } elseif ($left -is [System.Management.Automation.Language.IndexExpressionAst] -and
            $left.Target -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $left.Target.VariablePath.UserPath -ieq $SplatVarName -and
            $left.Index -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$left.Index.Value)
        }
    }

    # (c) metodo .Add('Chave', ...)
    $invokes = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $n.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Expression.VariablePath.UserPath -ieq $SplatVarName -and
                $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                $n.Member.Value -ieq 'Add'
            }, $true))
    foreach ($inv in $invokes) {
        $argList = @($inv.Arguments)
        if ($argList.Count -ge 1 -and $argList[0] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
            $keys.Add([string]$argList[0].Value)
        }
    }

    return @($keys)
}

function Test-XpzSplatVarMutated {
    <# True se a variavel de splat sofre .Remove/.Clear ou foi reatribuida >1 vez (nao-rastreavel). #>
    param([string]$SplatVarName, [System.Management.Automation.Language.Ast]$RootAst)

    $mutators = @($RootAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
                $n.Expression -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.Expression.VariablePath.UserPath -ieq $SplatVarName -and
                $n.Member -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
                ($n.Member.Value -ieq 'Remove' -or $n.Member.Value -ieq 'Clear')
            }, $true))
    return $mutators.Count -gt 0
}

function Get-XpzEngineAcceptedParam {
    <#
      Resolve o conjunto de parametros aceitos por um motor ADVANCED, ou um diagnostico.
      Devolve [pscustomobject]@{ Status; Accepted } onde Status e:
        'advanced'   -> Accepted = HashSet (OrdinalIgnoreCase) de nomes + aliases aceitos
        'simple'     -> motor nao-advanced (binder permissivo); nao auditavel
        'unparseable'-> parse-error/Get-Command falhou/Parameters nulo
        'dynamic'    -> motor declara DynamicParam (nao enxergavel estaticamente)
    #>
    param([string]$EngineFullPath)

    # Parse primario (fonte de unparseable).
    $perrs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($EngineFullPath, [ref]$null, [ref]$perrs)
    if ($null -ne $perrs -and @($perrs).Count -gt 0) {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }

    $cmd = $null
    try { $cmd = Get-Command -Name $EngineFullPath -ErrorAction Stop } catch {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }
    if ($null -eq $cmd -or $null -eq $cmd.Parameters) {
        return [pscustomobject]@{ Status = 'unparseable'; Accepted = $null }
    }

    # Guard DynamicParam (nao aparece estaticamente em Get-Command).
    $body = [System.IO.File]::ReadAllText($EngineFullPath)
    if ($body -imatch '(?m)^\s*dynamicparam\b') {
        return [pscustomobject]@{ Status = 'dynamic'; Accepted = $null }
    }

    $surface = @($cmd.Parameters.Keys)

    # Nomes declarados no param() block do AST (TrimStart '$').
    $declared = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $engineAst = [System.Management.Automation.Language.Parser]::ParseFile($EngineFullPath, [ref]$null, [ref]$null)
    $paramBlocks = @($engineAst.FindAll({
                param($n) $n -is [System.Management.Automation.Language.ParamBlockAst]
            }, $true))
    foreach ($pb in $paramBlocks) {
        foreach ($p in $pb.Parameters) {
            [void]$declared.Add(([string]$p.Name.VariablePath.UserPath))
        }
    }

    # injetados = surface - declarados.
    $injected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $surface) { if (-not $declared.Contains([string]$s)) { [void]$injected.Add([string]$s) } }

    $isAdvanced = $true
    foreach ($marker in $script:XpzEngineParamCommonMarkers) {
        if (-not $injected.Contains($marker)) { $isAdvanced = $false; break }
    }
    if (-not $isAdvanced) { return [pscustomobject]@{ Status = 'simple'; Accepted = $null } }

    $accepted = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($s in $surface) { [void]$accepted.Add([string]$s) }
    foreach ($pname in $cmd.Parameters.Keys) {
        foreach ($alias in @($cmd.Parameters[$pname].Aliases)) { [void]$accepted.Add([string]$alias) }
    }
    return [pscustomobject]@{ Status = 'advanced'; Accepted = $accepted }
}

function Get-XpzWrapperEngineParamFinding {
    <#
      Ponto de entrada. Para um wrapper local, devolve:
        [pscustomobject]@{
          Signals          = @( @{ Reason; Detail } )   # desvios-de-wrapper (-> INVENTORY_CUSTOMIZED)
          EngineDiagnostics = @( @{ Reason; Detail } )   # infra brando (-> INVENTORY_ENGINE_DIAGNOSTIC)
          AuditedSiteCount = <int>                        # nº de sites de motor advanced auditados
        }
      EnginesRoot = pasta dos motores canonicos do auditor (tipicamente $PSScriptRoot do inventory).
    #>
    param(
        [Parameter(Mandatory)][string]$WrapperPath,
        [Parameter(Mandatory)][string]$EnginesRoot
    )

    $signals = [System.Collections.Generic.List[object]]::new()
    $diagnostics = [System.Collections.Generic.List[object]]::new()
    $audited = 0

    $perrs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($WrapperPath, [ref]$null, [ref]$perrs)
    if ($null -eq $ast) {
        return [pscustomobject]@{ Signals = @(); EngineDiagnostics = @(); AuditedSiteCount = 0 }
    }

    $callSites = @($ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.CommandAst] -and
                $n.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand
            }, $true))

    foreach ($site in $callSites) {
        $elements = @($site.CommandElements)
        if ($elements.Count -lt 1) { continue }
        $target = Resolve-XpzEngineTarget -TargetAst $elements[0] -RootAst $ast
        if ($target.Kind -eq 'local' -or $target.Kind -eq 'unresolved') { continue }
        # target.Kind = 'shared'
        $leaf = $target.Leaf
        $enginePath = Join-Path $EnginesRoot $leaf
        if (-not (Test-Path -LiteralPath $enginePath -PathType Leaf)) {
            $signals.Add(@{ Reason = 'shared_engine_unresolved'; Detail = $leaf })
            continue
        }

        # Se a variavel de splat sofre mutacao nao-rastreavel, pular o site (conservador).
        $splatVar = $null
        for ($i = 1; $i -lt $elements.Count; $i++) {
            if ($elements[$i] -is [System.Management.Automation.Language.VariableExpressionAst] -and $elements[$i].Splatted) {
                $splatVar = $elements[$i].VariablePath.UserPath; break
            }
        }
        if ($splatVar -and (Test-XpzSplatVarMutated -SplatVarName $splatVar -RootAst $ast)) { continue }

        $engine = Get-XpzEngineAcceptedParam -EngineFullPath $enginePath
        # NOTA: 'continue' dentro de switch continua o switch, nao o foreach; por isso o
        # switch e a ultima instrucao do corpo do laco e cada caso so faz seu trabalho.
        switch ($engine.Status) {
            'unparseable' { $diagnostics.Add(@{ Reason = 'engine_unresolved_or_unparseable'; Detail = $leaf }) }
            'dynamic'     { }
            'simple'      { }
            'advanced' {
                $audited++
                $forwarded = Get-XpzForwardedParamName -CommandAst $site -RootAst $ast
                foreach ($name in $forwarded) {
                    if (-not $engine.Accepted.Contains([string]$name)) {
                        $signals.Add(@{ Reason = 'forwards_unknown_engine_param'; Detail = ('-{0} -> {1}' -f $name, $leaf) })
                    }
                }
            }
        }
    }

    return [pscustomobject]@{
        Signals           = @($signals)
        EngineDiagnostics = @($diagnostics)
        AuditedSiteCount  = $audited
    }
}
