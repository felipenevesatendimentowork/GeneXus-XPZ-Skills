#requires -Version 7.4

Set-StrictMode -Version Latest

# Gate fail-fast de -LogPath compartilhado pelos wrappers MSBuild.
#
# Motivacao: o -LogPath dos wrappers e resolvido cedo, mas sem validar que
# aponta para um ARQUIVO. Quando o chamador passa por engano um DIRETORIO
# existente como -LogPath, o wrapper roda a operacao inteira (abre KB, builda,
# importa) e so falha no fim, ao gravar o diagnostico JSON via
# [System.IO.File]::WriteAllText(<diretorio>, ...): a escrita estoura "Access
# denied", o wrapper cai no catch e retorna exit 90 ("falha operacional"),
# parecendo falha de build quando a operacao na verdade concluiu. O guard
# existente em volta da escrita so checa o diretorio-PAI, e um diretorio
# existente passa nesse gate.
#
# Este motor e a fonte unica da decisao do gate. Escopo minimo e deliberado:
# "o -LogPath resolvido e um diretorio existente?". A condicao e
# Test-Path -PathType Container (NUNCA -not -PathType Leaf), para nao bloquear
# o caso legitimo de arquivo-a-criar (-LogPath ainda inexistente com pai valido).
#
# O motor e funcao pura: NAO grava nada e NAO resolve caminho (recebe o
# -LogPath ja resolvido pelo Get-FullPathSafe local de cada wrapper, para nao
# substituir os helpers que cada wrapper redefine). O wrapper emite o JSON de
# bloqueio so no stdout (sem Write-JsonLog), porque o proprio -LogPath e o alvo
# invalido e gravar nele reintroduziria a falha que o gate evita.

function Get-GeneXusMsBuildLogPathRejection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$ResolvedLogPath
    )

    if ([string]::IsNullOrWhiteSpace($ResolvedLogPath)) {
        return [pscustomobject]@{
            rejected        = $false
            reason          = $null
            resolvedLogPath = $ResolvedLogPath
        }
    }

    if (Test-Path -LiteralPath $ResolvedLogPath -PathType Container) {
        $reason = "O -LogPath resolvido aponta para um diretorio existente ($ResolvedLogPath); informe um caminho de ARQUIVO de log (ex.: <pasta>/build.log). O wrapper grava o diagnostico JSON nesse arquivo; um diretorio faria a operacao concluir e so falhar na gravacao final, mascarando o resultado como falha operacional (exit 90)."
        return [pscustomobject]@{
            rejected        = $true
            reason          = $reason
            resolvedLogPath = $ResolvedLogPath
        }
    }

    return [pscustomobject]@{
        rejected        = $false
        reason          = $null
        resolvedLogPath = $ResolvedLogPath
    }
}

function New-GeneXusMsBuildLogPathBlockJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$WrapperName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ResolvedLogPath,

        [Parameter(Mandatory = $true)]
        [string]$Reason
    )

    $block = [ordered]@{
        status           = 'bloqueado por parametro invalido'
        summary          = $Reason
        exitCode         = 50
        stage            = 'pre-validate-logpath'
        wrapper          = $WrapperName
        requestedContext = [ordered]@{
            LogPathIsExistingDirectory = $true
        }
        resolvedPaths    = [ordered]@{
            LogPath = $ResolvedLogPath
        }
        blockingReasons  = @($Reason)
    }

    return ($block | ConvertTo-Json -Depth 8)
}
