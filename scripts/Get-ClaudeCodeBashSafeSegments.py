#!/usr/bin/env python3
# Get-ClaudeCodeBashSafeSegments.py - parte do hook PreToolUse do CLAUDE CODE (auto-allow).
# (O lexing em si e agnostico de agente, mas integra a solucao especifica do Claude Code.)
# Ver claude-code-pretooluse-auto-allow-design.md (secao 4).
#
# Tokeniza um comando Bash com shlex (parser de verdade, nao regex) e devolve os
# SEGMENTOS de um pipeline simples e seguro, OU 'defer'. Conservador por desenho:
# qualquer duvida -> defer (fail-closed). O classificador de verbo/flag fica no
# PowerShell (ClaudeCodePreToolUseSafeAllowSupport.ps1); este helper so faz o lexing seguro.
#
# Contrato: le o comando cru do stdin; emite 1 linha JSON no stdout:
#   {"status":"ok","segments":[["git","log"],["head"]]}
#   {"status":"defer","reason":"<motivo>"}
import sys
import json
import shlex

# Separadores de segmento de pipeline aceitos (estrutura permitida).
SEPARATORS = {"|", "||", "&&", ";"}
# Caracteres de pontuacao que o shlex (punctuation_chars=True) agrupa em tokens
# proprios. Um token feito so destes que NAO seja separador (redirecao >, subshell
# (), background &, here-doc <<, merge 2>&1 ...) -> defer.
PUNCT = set("();<>|&")
# Expansao / substituicao / brace dentro de um token -> defer (nao sabemos provar
# seguro): $VAR, $(...), `...`, ${...}, {a,b}.
DANGER_IN_TOKEN = set("$`{}")


def emit(obj):
    sys.stdout.write(json.dumps(obj))


def main():
    cmd = sys.stdin.read()
    if not cmd or not cmd.strip():
        emit({"status": "defer", "reason": "empty"})
        return
    # Multi-linha: newline pode separar comandos; nao tratamos -> defer.
    if "\n" in cmd.strip():
        emit({"status": "defer", "reason": "multiline"})
        return
    try:
        lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
        lex.whitespace_split = True
        tokens = list(lex)
    except ValueError:
        # Aspas desbalanceadas / lexing invalido -> defer.
        emit({"status": "defer", "reason": "lex-error"})
        return

    segments = []
    current = []
    for tok in tokens:
        if tok in SEPARATORS:
            segments.append(current)
            current = []
            continue
        if tok and all(c in PUNCT for c in tok):
            # Pontuacao que nao e separador: redirecao, subshell, background, etc.
            emit({"status": "defer", "reason": "punct"})
            return
        if any(c in DANGER_IN_TOKEN for c in tok):
            emit({"status": "defer", "reason": "danger-char"})
            return
        current.append(tok)
    segments.append(current)

    segments = [s for s in segments if s]
    if not segments:
        emit({"status": "defer", "reason": "no-segments"})
        return
    emit({"status": "ok", "segments": segments})


if __name__ == "__main__":
    main()
