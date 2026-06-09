@{
    # Contrato canonico de topicos minimos dos instrucionais globais auditados por
    # Test-XpzGlobalInstructions.ps1 (passo 9 de xpz-skills-setup).
    #
    # Fonte unica de verdade da DETECCAO. O bloco em prosa de
    # xpz-skills-setup/SKILL.md (secao "## AGENTS.MD RECOMENDADO") descreve os mesmos
    # topicos para humanos; o self-test de paridade garante que cada SkillHeading
    # abaixo exista naquele bloco, evitando drift silencioso entre doc e motor.
    #
    # Semantica conservadora (Camada 2): para cada topico, se QUALQUER padrao de
    # AnchorsAny casar no texto efetivo -> "presente"; se nenhum casar ->
    # "nao_detectado" (NUNCA "ausente"). nao_detectado significa "o agente revisa",
    # nao "falta, pode duplicar".
    #
    # AnchorsAny usa regex .NET, aplicado com IgnoreCase e Singleline.

    Topics = @(
        @{
            Id           = 'busca-shell'
            Label        = 'Ferramentas de busca e shell (cd + && proibido)'
            SkillHeading = '## Ferramentas de busca e shell'
            AnchorsAny   = @(
                'cd\b[^\r\n]*&&'
                'Compound command contains cd with path operation'
                'cd\b[^\r\n]*&&[^\r\n]*<comando>'
            )
        }
        @{
            Id           = 'cherry-pick-worktree'
            Label        = 'Cherry-pick em worktrees (hash literal, nunca refs relativas)'
            SkillHeading = '## Cherry-pick em worktrees'
            AnchorsAny   = @(
                'cherry-pick.{0,400}HEAD@\{0\}'
                'cherry-pick.{0,400}hash do commit literal'
                'HEAD@\{0\}.{0,400}cherry-pick'
            )
        }
    )
}
