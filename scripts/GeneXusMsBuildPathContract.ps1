#requires -Version 7.4

function Get-FullPathSafe {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }

    return [System.IO.Path]::GetFullPath($PathValue)
}

function Test-IsUnderProgramFilesX86 {
    param(
        [string]$PathValue,
        [string]$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)')
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $false
    }

    $fullPath = Get-FullPathSafe -PathValue $PathValue
    $candidate = $fullPath.TrimEnd('\')
    $root = $ProgramFilesX86.TrimEnd('\')
    return $candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-ExplicitWorkingDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue,

        [string]$ProgramFilesX86 = [System.IO.Path]::GetFullPath('C:\Program Files (x86)'),

        [int]$FailureCode = 13
    )

    $resolved = Get-FullPathSafe -PathValue $PathValue
    $checkName = 'WorkingDirectory outside Program Files x86'
    $invalidReason = "WorkingDirectory inválido ou inseguro: '{0}'." -f $resolved

    if ([string]::IsNullOrWhiteSpace($resolved)) {
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'WorkingDirectory não pôde ser resolvido para um caminho completo.'
            code = $FailureCode
            check = [ordered]@{
                name = $checkName
                result = 'fail'
                detail = 'WorkingDirectory não pôde ser resolvido para um caminho completo.'
            }
            autoCreated = $false
            pathAction = 'blocked-invalid'
            blockingReason = $invalidReason
            warning = $null
            strategyTrace = 'WorkingDirectory explícito não pôde ser resolvido e permaneceu bloqueado.'
        }
    }

    if (Test-IsUnderProgramFilesX86 -PathValue $resolved -ProgramFilesX86 $ProgramFilesX86) {
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'Diretório aponta para árvore estritamente somente leitura.'
            code = $FailureCode
            check = [ordered]@{
                name = $checkName
                result = 'fail'
                detail = 'Diretório aponta para árvore estritamente somente leitura.'
            }
            autoCreated = $false
            pathAction = 'blocked-readonly'
            blockingReason = $invalidReason
            warning = $null
            strategyTrace = 'WorkingDirectory explícito foi bloqueado por apontar para a árvore somente leitura.'
        }
    }

    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'O caminho informado existe como arquivo, não como diretório.'
            code = $FailureCode
            check = [ordered]@{
                name = $checkName
                result = 'fail'
                detail = 'O caminho informado existe como arquivo, não como diretório.'
            }
            autoCreated = $false
            pathAction = 'blocked-file'
            blockingReason = $invalidReason
            warning = $null
            strategyTrace = 'WorkingDirectory explícito foi bloqueado porque aponta para um arquivo existente.'
        }
    }

    if (Test-Path -LiteralPath $resolved -PathType Container) {
        return [ordered]@{
            path = $resolved
            result = 'ok'
            detail = 'Diretório válido e fora da árvore somente leitura.'
            code = 0
            check = [ordered]@{
                name = $checkName
                result = 'ok'
                detail = 'Diretório válido e fora da árvore somente leitura.'
            }
            autoCreated = $false
            pathAction = 'validated-existing'
            blockingReason = $null
            warning = $null
            strategyTrace = 'WorkingDirectory explícito já existia e foi validado como seguro.'
        }
    }

    try {
        [System.IO.Directory]::CreateDirectory($resolved) | Out-Null
        return [ordered]@{
            path = $resolved
            result = 'ok'
            detail = 'Diretório ausente no caminho seguro informado; pasta auto-criada.'
            code = 0
            check = [ordered]@{
                name = $checkName
                result = 'ok'
                detail = 'Diretório ausente no caminho seguro informado; pasta auto-criada.'
            }
            autoCreated = $true
            pathAction = 'validated-and-created'
            blockingReason = $null
            warning = ('WorkingDirectory ausente foi criado automaticamente no caminho explícito e seguro: {0}' -f $resolved)
            strategyTrace = 'WorkingDirectory explícito não existia; o script criou exatamente o diretório informado após validar segurança.'
        }
    }
    catch {
        return [ordered]@{
            path = $resolved
            result = 'fail'
            detail = 'Falha ao criar o diretório explícito informado após validação de segurança.'
            code = $FailureCode
            check = [ordered]@{
                name = $checkName
                result = 'fail'
                detail = 'Falha ao criar o diretório explícito informado após validação de segurança.'
            }
            autoCreated = $false
            pathAction = 'blocked-create-failed'
            blockingReason = ("WorkingDirectory inválido ou inseguro: '{0}'. Falha ao criar a pasta explícita: {1}" -f $resolved, $_.Exception.Message)
            warning = $null
            strategyTrace = 'WorkingDirectory explícito passou na validação de segurança, mas a criação da pasta falhou.'
        }
    }
}

function Get-VsWhereExecutablePath {
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'),
        (Join-Path $env:ProgramFiles 'Microsoft Visual Studio\Installer\vswhere.exe')
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Get-FullPathSafe -PathValue $candidate)
        }
    }

    return $null
}

function Get-MsBuildStaticCandidatePaths {
    $paths = New-Object System.Collections.Generic.List[string]
    $trees = @(
        @{ Base = 'C:\Program Files\Microsoft Visual Studio'; Versions = @('18', '2022') },
        @{ Base = 'C:\Program Files (x86)\Microsoft Visual Studio'; Versions = @('2022', '2019') }
    )
    $editions = @('BuildTools', 'Enterprise', 'Professional', 'Community')
    $relativePaths = @(
        'MSBuild\Current\Bin\MSBuild.exe',
        'MSBuild\Current\Bin\amd64\MSBuild.exe'
    )

    foreach ($tree in $trees) {
        foreach ($version in $tree.Versions) {
            foreach ($edition in $editions) {
                foreach ($relativePath in $relativePaths) {
                    $paths.Add((Join-Path $tree.Base (Join-Path $version (Join-Path $edition $relativePath))))
                }
            }
        }
    }

    return @($paths)
}

function Add-UniqueMsBuildCatalogEntry {
    param(
        [System.Collections.Generic.List[object]]$Catalog,
        [string]$PathValue,
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return
    }

    $normalized = Get-FullPathSafe -PathValue $PathValue
    foreach ($existing in $Catalog) {
        if ($existing.path.Equals($normalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            return
        }
    }

    [void]$Catalog.Add([ordered]@{
            path   = $normalized
            source = $Source
        })
}

function Get-VsWhereMsBuildCandidatePaths {
    param(
        [ref]$VsWhereDiagnostics
    )

    $vswherePath = Get-VsWhereExecutablePath
    $diagnostics = [ordered]@{
        executablePath = $vswherePath
        invoked        = $false
        exitCode       = $null
        errorMessage   = $null
        findPatterns   = @('MSBuild\Current\Bin\MSBuild.exe', 'MSBuild\Current\Bin\amd64\MSBuild.exe')
        discovered     = @()
    }

    if ([string]::IsNullOrWhiteSpace($vswherePath)) {
        $diagnostics.errorMessage = 'vswhere.exe não encontrado nos caminhos padrão do instalador do Visual Studio.'
        $VsWhereDiagnostics.Value = $diagnostics
        return @()
    }

    $discovered = New-Object System.Collections.Generic.List[string]
    $findPatterns = @('MSBuild\Current\Bin\MSBuild.exe', 'MSBuild\Current\Bin\amd64\MSBuild.exe')

    foreach ($findPattern in $findPatterns) {
        try {
            $output = & $vswherePath -all -sort -requires Microsoft.Component.MSBuild -find $findPattern 2>&1
            $exitCode = $LASTEXITCODE
            $diagnostics.invoked = $true
            $diagnostics.exitCode = $exitCode

            if ($exitCode -ne 0) {
                $diagnostics.errorMessage = ('vswhere retornou exit {0} ao buscar {1}.' -f $exitCode, $findPattern)
                continue
            }

            foreach ($line in @($output)) {
                $trimmed = [string]$line
                if ([string]::IsNullOrWhiteSpace($trimmed)) {
                    continue
                }

                if (-not $discovered.Contains($trimmed)) {
                    $discovered.Add($trimmed)
                }
            }
        }
        catch {
            $diagnostics.errorMessage = $_.Exception.Message
        }
    }

    $diagnostics.discovered = @($discovered)
    $VsWhereDiagnostics.Value = $diagnostics
    return @($discovered)
}

function Get-MsBuildCandidateCatalog {
    $catalog = New-Object System.Collections.Generic.List[object]
    $vswhereDiagnostics = $null
    $vswherePaths = Get-VsWhereMsBuildCandidatePaths -VsWhereDiagnostics ([ref]$vswhereDiagnostics)

    foreach ($pathValue in $vswherePaths) {
        Add-UniqueMsBuildCatalogEntry -Catalog $catalog -PathValue $pathValue -Source 'vswhere'
    }

    foreach ($pathValue in Get-MsBuildStaticCandidatePaths) {
        Add-UniqueMsBuildCatalogEntry -Catalog $catalog -PathValue $pathValue -Source 'static'
    }

    return [ordered]@{
        catalog            = $catalog.ToArray()
        vsWhereDiagnostics = $vswhereDiagnostics
    }
}

function New-MsBuildProbeFromCatalog {
    param(
        [array]$Catalog,
        $VsWhereDiagnostics,
        [string]$ResolutionSource,
        [string]$SelectedPath
    )

    $candidates = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Catalog) {
        $exists = Test-Path -LiteralPath $entry.path -PathType Leaf
        $selected = (-not [string]::IsNullOrWhiteSpace($SelectedPath)) -and
            $entry.path.Equals($SelectedPath, [System.StringComparison]::OrdinalIgnoreCase)
        [void]$candidates.Add([ordered]@{
                path     = $entry.path
                source   = $entry.source
                exists   = $exists
                selected = $selected
            })
    }

    return [ordered]@{
        resolutionSource = $ResolutionSource
        vsWhere          = $VsWhereDiagnostics
        candidates       = $candidates.ToArray()
    }
}

function Resolve-MsBuildExecutableFromCatalog {
    param(
        [string]$ExplicitMsBuildPath,
        [scriptblock]$AddStrategyTrace,
        [scriptblock]$AddBlockingReason
    )

    if (-not [string]::IsNullOrWhiteSpace($ExplicitMsBuildPath)) {
        $resolved = Get-FullPathSafe -PathValue $ExplicitMsBuildPath
        $null = $AddStrategyTrace.Invoke('MsBuildPath usado conforme parâmetro explícito.')
        $exists = Test-Path -LiteralPath $resolved -PathType Leaf
        $probe = [ordered]@{
            resolutionSource = 'explicit'
            vsWhere          = [ordered]@{
                executablePath = (Get-VsWhereExecutablePath)
                invoked        = $false
                exitCode       = $null
                errorMessage   = $null
                findPatterns   = @()
                discovered     = @()
            }
            candidates       = @(
                [ordered]@{
                    path     = $resolved
                    source   = 'explicit'
                    exists   = $exists
                    selected = $exists
                }
            )
        }

        if (-not $exists) {
            $null = $AddBlockingReason.Invoke(("MsBuildPath inválido: '{0}'." -f $resolved))
            return [ordered]@{
                path       = $resolved
                result     = 'fail'
                detail     = 'Executável informado não foi encontrado.'
                code       = 11
                msBuildProbe = $probe
            }
        }

        return [ordered]@{
            path         = $resolved
            result       = 'ok'
            detail       = 'Executável informado encontrado.'
            code         = 0
            msBuildProbe = $probe
        }
    }

    $catalogPlan = Get-MsBuildCandidateCatalog
    $catalog = @($catalogPlan.catalog)
    $matches = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $catalog) {
        if (Test-Path -LiteralPath $entry.path -PathType Leaf) {
            $matches.Add((Get-FullPathSafe -PathValue $entry.path))
        }
    }

    if ($matches.Count -gt 0) {
        $selected = $matches[0]
        $selectedEntry = $catalog | Where-Object { $_.path.Equals($selected, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
        $resolutionSource = if ($null -ne $selectedEntry) { $selectedEntry.source } else { 'unknown' }

        $null = $AddStrategyTrace.Invoke(
            ('MsBuildPath não informado; descoberta via {0}. Selecionado: {1}' -f $resolutionSource, $selected))

        $discarded = @($matches | Select-Object -Skip 1)
        if ($discarded.Count -gt 0) {
            $null = $AddStrategyTrace.Invoke(('Candidatos de MSBuild descartados: {0}' -f ($discarded -join '; ')))
        }

        if ($null -ne $catalogPlan.vsWhereDiagnostics -and $catalogPlan.vsWhereDiagnostics.invoked) {
            $null = $AddStrategyTrace.Invoke(
                ('vswhere: {0} caminho(s) reportado(s); exit {1}.' -f $catalogPlan.vsWhereDiagnostics.discovered.Count, $catalogPlan.vsWhereDiagnostics.exitCode))
        }
        elseif ($null -ne $catalogPlan.vsWhereDiagnostics -and -not [string]::IsNullOrWhiteSpace($catalogPlan.vsWhereDiagnostics.errorMessage)) {
            $null = $AddStrategyTrace.Invoke(('vswhere não contribuiu: {0}' -f $catalogPlan.vsWhereDiagnostics.errorMessage))
        }

        $probe = New-MsBuildProbeFromCatalog -Catalog $catalog -VsWhereDiagnostics $catalogPlan.vsWhereDiagnostics `
            -ResolutionSource $resolutionSource -SelectedPath $selected

        return [ordered]@{
            path         = $selected
            result       = 'ok'
            detail       = ('MSBuild localizado por fallback ({0}).' -f $resolutionSource)
            code         = 0
            msBuildProbe = $probe
        }
    }

    $null = $AddStrategyTrace.Invoke('MsBuildPath não informado; catálogo vswhere + caminhos estáticos esgotado sem executável válido.')
    if ($null -ne $catalogPlan.vsWhereDiagnostics -and $catalogPlan.vsWhereDiagnostics.invoked) {
        $null = $AddStrategyTrace.Invoke(
            ('vswhere executado (exit {0}); nenhum MSBuild.exe existente no catalogo unificado.' -f $catalogPlan.vsWhereDiagnostics.exitCode))
    }

    $null = $AddBlockingReason.Invoke('MSBuild.exe não localizado.')
    $probe = New-MsBuildProbeFromCatalog -Catalog $catalog -VsWhereDiagnostics $catalogPlan.vsWhereDiagnostics `
        -ResolutionSource 'none' -SelectedPath $null

    return [ordered]@{
        path         = $null
        result       = 'fail'
        detail       = 'Nenhum caminho conhecido de MSBuild foi encontrado.'
        code         = 11
        msBuildProbe = $probe
    }
}
