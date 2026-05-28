-- ============================================================================
-- MÓDULO 3 — SCRIPT V4: ÁREA DE DADOS ANALÍTICA
-- ============================================================================
-- Base de dados alvo: aluno_online (PRODUÇÃO)
-- Problema: Identificação de Alunos em Risco de Reprovação e Evasão
--
-- Este módulo cria um ecossistema analítico completo dentro do PostgreSQL:
--   • Functions: cálculos de métricas específicas (média, desvio padrão, etc.)
--   • Materialized Views: consolidação de dados complexos, pré-computados
--   • Stored Procedures: processamento de regras de negócio pesadas
--
-- FLUXO ANALÍTICO:
--   1. Functions calculam métricas individuais
--   2. Materialized Views agregam essas métricas em visões consolidadas
--   3. Stored Procedures orquestram o pipeline (refresh + processamento)
--
-- Score de Risco (0-100):
--   Baseado em: % reprovações, % trancamentos, média global, desvio negativo
--   Classificação: BAIXO (0-25), MODERADO (26-50), ALTO (51-75), CRITICO (76-100)
-- ============================================================================


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                         F U N C T I O N S                               ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_calcular_media_aluno(p_aluno_id BIGINT)
-- Propósito: Calcula a média global de um aluno em todas as disciplinas
--            onde possui nota1 e nota2 lançadas
-- Retorno: NUMERIC(5,2) — média ponderada global (ou NULL se sem notas)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_calcular_media_aluno(p_aluno_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE  -- Indica que a função não modifica dados e é segura para otimização
AS $$
DECLARE
    v_media NUMERIC(5,2);
BEGIN
    -- Calcula a média de todas as médias individuais (nota1+nota2)/2
    -- Apenas considera matrículas com ambas as notas preenchidas
    SELECT ROUND(AVG((ma.nota1 + ma.nota2) / 2.0)::NUMERIC, 2)
    INTO v_media
    FROM public.matricula_aluno ma
    WHERE ma.aluno_id = p_aluno_id
      AND ma.nota1 IS NOT NULL
      AND ma.nota2 IS NOT NULL;

    RETURN v_media;
END;
$$;

COMMENT ON FUNCTION fn_calcular_media_aluno(BIGINT) IS
'Calcula a média global de um aluno considerando todas as disciplinas com notas completas.
Exemplo: SELECT fn_calcular_media_aluno(1);';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_desvio_padrao_notas(p_disciplina_id BIGINT)
-- Propósito: Calcula o desvio padrão das médias dos alunos numa disciplina
--            Permite identificar disciplinas com grande dispersão de notas
-- Retorno: NUMERIC(5,2) — desvio padrão (0 = notas homogéneas)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_desvio_padrao_notas(p_disciplina_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE SET search_path TO public
AS $$
DECLARE
    v_desvio NUMERIC(5,2);
BEGIN
    -- STDDEV_POP: desvio padrão populacional (não amostral)
    -- Usa a média individual de cada aluno (nota1+nota2)/2 como base
    SELECT ROUND(STDDEV_POP((ma.nota1 + ma.nota2) / 2.0)::NUMERIC, 2)
    INTO v_desvio
    FROM public.matricula_aluno ma
    WHERE ma.disciplina_id = p_disciplina_id
      AND ma.nota1 IS NOT NULL
      AND ma.nota2 IS NOT NULL;

    -- Retorna 0 se não houver dados suficientes (NULL do STDDEV)
    RETURN COALESCE(v_desvio, 0);
END;
$$;

COMMENT ON FUNCTION fn_desvio_padrao_notas(BIGINT) IS
'Calcula o desvio padrão das médias numa disciplina. Valores altos indicam grande dispersão de desempenho.
Exemplo: SELECT fn_desvio_padrao_notas(1);';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_taxa_aprovacao_disciplina(p_disciplina_id BIGINT)
-- Propósito: Calcula a percentagem de aprovação numa disciplina
-- Retorno: NUMERIC(5,2) — percentagem (0.00 a 100.00)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_taxa_aprovacao_disciplina(p_disciplina_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE SET search_path TO public
AS $$
DECLARE
    v_total INTEGER;
    v_aprovados INTEGER;
BEGIN
    -- Conta apenas matrículas com resultado final (APROVADO ou REPROVADO)
    SELECT
        COUNT(*),
        COUNT(CASE WHEN status = 'APROVADO' THEN 1 END)
    INTO v_total, v_aprovados
    FROM public.matricula_aluno
    WHERE disciplina_id = p_disciplina_id
      AND status IN ('APROVADO', 'REPROVADO');

    -- Evitar divisão por zero
    IF v_total = 0 THEN
        RETURN NULL;
    END IF;

    RETURN ROUND((v_aprovados::NUMERIC / v_total * 100), 2);
END;
$$;

COMMENT ON FUNCTION fn_taxa_aprovacao_disciplina(BIGINT) IS
'Retorna a taxa de aprovação (%) de uma disciplina, considerando apenas matrículas finalizadas.
Exemplo: SELECT fn_taxa_aprovacao_disciplina(1);';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_contar_por_status(p_aluno_id BIGINT, p_status VARCHAR)
-- Propósito: Conta quantas matrículas um aluno tem com determinado status
-- Retorno: INTEGER
-- Uso interno: utilizada pelo score de risco
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_contar_por_status(p_aluno_id BIGINT, p_status VARCHAR)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE SET search_path TO public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM public.matricula_aluno
    WHERE aluno_id = p_aluno_id
      AND status = p_status;

    RETURN v_count;
END;
$$;

COMMENT ON FUNCTION fn_contar_por_status(BIGINT, VARCHAR) IS
'Conta matrículas de um aluno filtrando por status. Função auxiliar do score de risco.';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_score_risco_aluno(p_aluno_id BIGINT)
-- Propósito: Calcula um score de risco (0-100) para um aluno
--
-- FÓRMULA DO SCORE:
--   score = (35 × % reprovações)
--         + (20 × % trancamentos)
--         + (30 × penalidade_media)     -- onde penalidade = (10 - média) / 10
--         + (15 × penalidade_desvio)    -- desvio negativo em relação à turma
--
-- PESOS:
--   Reprovações: 35% — indicador mais forte de risco
--   Média baixa: 30% — segundo indicador mais relevante
--   Trancamentos: 20% — sinal de desmotivação/dificuldade
--   Desvio negativo: 15% — abaixo da média da turma
--
-- Retorno: NUMERIC(5,2) — score de 0 (sem risco) a 100 (risco máximo)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_score_risco_aluno(p_aluno_id BIGINT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
STABLE SET search_path TO public
AS $$
DECLARE
    v_total_matriculas INTEGER;
    v_reprovacoes INTEGER;
    v_trancamentos INTEGER;
    v_media_global NUMERIC(5,2);
    v_media_geral_sistema NUMERIC(5,2);

    -- Percentuais e penalidades
    v_pct_reprovacoes NUMERIC(5,2);
    v_pct_trancamentos NUMERIC(5,2);
    v_penalidade_media NUMERIC(5,2);
    v_penalidade_desvio NUMERIC(5,2);

    -- Score final
    v_score NUMERIC(5,2);

    -- Pesos (somam 100)
    PESO_REPROVACAO CONSTANT NUMERIC := 35;
    PESO_TRANCAMENTO CONSTANT NUMERIC := 20;
    PESO_MEDIA CONSTANT NUMERIC := 30;
    PESO_DESVIO CONSTANT NUMERIC := 15;
BEGIN
    -- ─── Obter contadores ─────────────────────────────────────────
    SELECT COUNT(*) INTO v_total_matriculas
    FROM public.matricula_aluno WHERE aluno_id = p_aluno_id;

    -- Se não há matrículas, não há dados para calcular risco
    IF v_total_matriculas = 0 THEN
        RETURN 0;
    END IF;

    v_reprovacoes := fn_contar_por_status(p_aluno_id, 'REPROVADO');
    v_trancamentos := fn_contar_por_status(p_aluno_id, 'TRANCADO');
    v_media_global := fn_calcular_media_aluno(p_aluno_id);

    -- Média geral de todos os alunos do sistema (referência)
    SELECT ROUND(AVG((nota1 + nota2) / 2.0)::NUMERIC, 2)
    INTO v_media_geral_sistema
    FROM public.matricula_aluno
    WHERE nota1 IS NOT NULL AND nota2 IS NOT NULL;

    -- ─── Calcular percentuais ─────────────────────────────────────
    v_pct_reprovacoes := (v_reprovacoes::NUMERIC / v_total_matriculas);
    v_pct_trancamentos := (v_trancamentos::NUMERIC / v_total_matriculas);

    -- Penalidade por média baixa: quanto menor a média, maior a penalidade
    -- Escala: 10.0 → 0 (sem penalidade), 0.0 → 1.0 (penalidade máxima)
    IF v_media_global IS NOT NULL THEN
        v_penalidade_media := GREATEST(0, (10.0 - v_media_global) / 10.0);
    ELSE
        -- Sem notas lançadas: penalidade moderada (não tem dados suficientes)
        v_penalidade_media := 0.5;
    END IF;

    -- Penalidade por desvio negativo: abaixo da média geral do sistema
    IF v_media_global IS NOT NULL AND v_media_geral_sistema IS NOT NULL THEN
        IF v_media_global < v_media_geral_sistema THEN
            v_penalidade_desvio := LEAST(1.0,
                (v_media_geral_sistema - v_media_global) / GREATEST(v_media_geral_sistema, 1)
            );
        ELSE
            v_penalidade_desvio := 0;
        END IF;
    ELSE
        v_penalidade_desvio := 0.3;  -- Valor moderado quando sem dados
    END IF;

    -- ─── Calcular score final ─────────────────────────────────────
    v_score := (PESO_REPROVACAO * v_pct_reprovacoes)
             + (PESO_TRANCAMENTO * v_pct_trancamentos)
             + (PESO_MEDIA * v_penalidade_media)
             + (PESO_DESVIO * v_penalidade_desvio);

    -- Limitar ao intervalo [0, 100]
    v_score := GREATEST(0, LEAST(100, v_score));

    RETURN ROUND(v_score, 2);
END;
$$;

COMMENT ON FUNCTION fn_score_risco_aluno(BIGINT) IS
'Calcula o score de risco de evasão/reprovação de um aluno (0-100).
Pesos: Reprovações 35%, Média baixa 30%, Trancamentos 20%, Desvio negativo 15%.
Exemplo: SELECT fn_score_risco_aluno(1);';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNCTION: fn_classificar_risco(p_score NUMERIC)
-- Propósito: Converte o score numérico numa classificação textual
-- Retorno: VARCHAR — 'BAIXO', 'MODERADO', 'ALTO' ou 'CRITICO'
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_classificar_risco(p_score NUMERIC)
RETURNS VARCHAR
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    RETURN CASE
        WHEN p_score <= 25 THEN 'BAIXO'
        WHEN p_score <= 50 THEN 'MODERADO'
        WHEN p_score <= 75 THEN 'ALTO'
        ELSE 'CRITICO'
    END;
END;
$$;

COMMENT ON FUNCTION fn_classificar_risco(NUMERIC) IS
'Classifica o score de risco: BAIXO (0-25), MODERADO (26-50), ALTO (51-75), CRITICO (76-100).';


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                  M A T E R I A L I Z E D   V I E W S                    ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALIZED VIEW: mv_historico_academico_consolidado
-- Propósito: Consolida o histórico completo de cada aluno com métricas
--            calculadas. Permite consultas rápidas sem recálculo.
--
-- Métricas por aluno:
--   - Total de disciplinas (todas as matrículas)
--   - Disciplinas aprovadas, reprovadas, trancadas, em curso
--   - Média global (calculada pela function)
--   - Percentagens de aprovação e reprovação
-- ═══════════════════════════════════════════════════════════════════════════
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_historico_academico_consolidado AS
SELECT
    a.id                    AS aluno_id,
    a.nome_completo         AS aluno_nome,
    a.email                 AS aluno_email,

    -- Contadores por status
    COUNT(ma.id)                                                AS total_disciplinas,
    COUNT(CASE WHEN ma.status = 'APROVADO'    THEN 1 END)      AS qtd_aprovadas,
    COUNT(CASE WHEN ma.status = 'REPROVADO'   THEN 1 END)      AS qtd_reprovadas,
    COUNT(CASE WHEN ma.status = 'TRANCADO'    THEN 1 END)      AS qtd_trancadas,
    COUNT(CASE WHEN ma.status = 'MATRICULADO' THEN 1 END)      AS qtd_em_curso,
    COUNT(CASE WHEN ma.status = 'DESLIGADO'   THEN 1 END)      AS qtd_desligadas,

    -- Média global do aluno (usa a function dedicada)
    fn_calcular_media_aluno(a.id)                               AS media_global,

    -- Percentagens
    ROUND(
        COUNT(CASE WHEN ma.status = 'APROVADO' THEN 1 END)::NUMERIC
        / NULLIF(COUNT(ma.id), 0) * 100, 2
    )                                                           AS pct_aprovacao,
    ROUND(
        COUNT(CASE WHEN ma.status = 'REPROVADO' THEN 1 END)::NUMERIC
        / NULLIF(COUNT(ma.id), 0) * 100, 2
    )                                                           AS pct_reprovacao,
    ROUND(
        COUNT(CASE WHEN ma.status = 'TRANCADO' THEN 1 END)::NUMERIC
        / NULLIF(COUNT(ma.id), 0) * 100, 2
    )                                                           AS pct_trancamento,

    -- Timestamp de quando esta MV foi atualizada
    CURRENT_TIMESTAMP                                           AS data_atualizacao

FROM public.aluno a
LEFT JOIN matricula_aluno ma ON ma.aluno_id = a.id
GROUP BY a.id, a.nome_completo, a.email;

-- Índice único para permitir REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_historico_aluno_id
    ON mv_historico_academico_consolidado(aluno_id);

COMMENT ON MATERIALIZED VIEW mv_historico_academico_consolidado IS
'Histórico académico consolidado por aluno: contadores de status, média global e percentagens.
Atualizar com: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_historico_academico_consolidado;';


-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALIZED VIEW: mv_panorama_disciplinas
-- Propósito: Análise estatística por disciplina — métricas de turma
-- Inclui: nº alunos, média, desvio padrão, taxas de aprovação/reprovação
-- ═══════════════════════════════════════════════════════════════════════════
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_panorama_disciplinas AS
SELECT
    d.id                    AS disciplina_id,
    d.nome                  AS disciplina_nome,
    d.carga_horaria         AS carga_horaria,
    p.nome                  AS professor_nome,

    -- Contadores
    COUNT(ma.id)                                                AS total_matriculas,
    COUNT(CASE WHEN ma.status = 'APROVADO'  THEN 1 END)        AS qtd_aprovados,
    COUNT(CASE WHEN ma.status = 'REPROVADO' THEN 1 END)        AS qtd_reprovados,
    COUNT(CASE WHEN ma.status = 'TRANCADO'  THEN 1 END)        AS qtd_trancados,

    -- Média da turma
    ROUND(AVG(
        CASE
            WHEN ma.nota1 IS NOT NULL AND ma.nota2 IS NOT NULL
                THEN (ma.nota1 + ma.nota2) / 2.0
        END
    )::NUMERIC, 2)                                              AS media_turma,

    -- Desvio padrão (usa a function dedicada)
    fn_desvio_padrao_notas(d.id)                                AS desvio_padrao,

    -- Taxa de aprovação (usa a function dedicada)
    fn_taxa_aprovacao_disciplina(d.id)                           AS taxa_aprovacao_pct,

    -- Taxa de reprovação
    ROUND(
        COUNT(CASE WHEN ma.status = 'REPROVADO' THEN 1 END)::NUMERIC
        / NULLIF(COUNT(CASE WHEN ma.status IN ('APROVADO', 'REPROVADO') THEN 1 END), 0)
        * 100, 2
    )                                                           AS taxa_reprovacao_pct,

    CURRENT_TIMESTAMP                                           AS data_atualizacao

FROM public.disciplina d
LEFT JOIN professor p        ON p.id = d.professor_id
LEFT JOIN matricula_aluno ma ON ma.disciplina_id = d.id
GROUP BY d.id, d.nome, d.carga_horaria, p.nome;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_panorama_disc_id
    ON mv_panorama_disciplinas(disciplina_id);

COMMENT ON MATERIALIZED VIEW mv_panorama_disciplinas IS
'Panorama estatístico por disciplina: média da turma, desvio padrão, taxas de aprovação e reprovação.
Atualizar com: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_panorama_disciplinas;';


-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALIZED VIEW: mv_alunos_em_risco
-- Propósito: Lista de todos os alunos com score e classificação de risco
--            Pré-computa os scores para consulta rápida pela API
--
-- Esta é a MV central do módulo analítico — alimenta o endpoint de
-- "alunos em risco" e permite filtrar por classificação
-- ═══════════════════════════════════════════════════════════════════════════
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_alunos_em_risco AS
SELECT
    a.id                                        AS aluno_id,
    a.nome_completo                             AS aluno_nome,
    a.email                                     AS aluno_email,

    -- Indicadores
    fn_calcular_media_aluno(a.id)               AS media_global,
    fn_contar_por_status(a.id, 'REPROVADO')     AS qtd_reprovacoes,
    fn_contar_por_status(a.id, 'TRANCADO')      AS qtd_trancamentos,
    fn_contar_por_status(a.id, 'MATRICULADO')   AS qtd_em_curso,

    -- Score e classificação de risco
    fn_score_risco_aluno(a.id)                  AS score_risco,
    fn_classificar_risco(fn_score_risco_aluno(a.id)) AS classificacao_risco,

    -- Total de matrículas (para contexto)
    (SELECT COUNT(*) FROM public.matricula_aluno WHERE aluno_id = a.id) AS total_matriculas,

    CURRENT_TIMESTAMP                           AS data_atualizacao

FROM public.aluno a
-- Apenas incluir alunos que têm pelo menos uma matrícula
WHERE EXISTS (SELECT 1 FROM public.matricula_aluno WHERE aluno_id = a.id)
-- Ordenar pelo score de risco (mais altos primeiro)
ORDER BY fn_score_risco_aluno(a.id) DESC;

CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_risco_aluno_id
    ON mv_alunos_em_risco(aluno_id);

CREATE INDEX IF NOT EXISTS idx_mv_risco_classificacao
    ON mv_alunos_em_risco(classificacao_risco);

COMMENT ON MATERIALIZED VIEW mv_alunos_em_risco IS
'Alunos com score e classificação de risco de evasão/reprovação.
Filtrável por classificacao_risco: BAIXO, MODERADO, ALTO, CRITICO.
Atualizar com: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_alunos_em_risco;';


-- ╔══════════════════════════════════════════════════════════════════════════╗
-- ║                  S T O R E D   P R O C E D U R E S                      ║
-- ╚══════════════════════════════════════════════════════════════════════════╝

-- ═══════════════════════════════════════════════════════════════════════════
-- PROCEDURE: sp_refresh_todas_mvs()
-- Propósito: Atualiza todas as materialized views de forma atómica
-- Usa CONCURRENTLY para não bloquear leituras durante o refresh
-- Ordem: histórico → panorama → risco (respeita dependências lógicas)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_refresh_todas_mvs()
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE '[Analytics] Iniciando refresh de todas as MVs...';

    -- 1. Histórico académico (base para as demais)
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_historico_academico_consolidado;
    RAISE NOTICE '[Analytics] mv_historico_academico_consolidado atualizada.';

    -- 2. Panorama de disciplinas
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_panorama_disciplinas;
    RAISE NOTICE '[Analytics] mv_panorama_disciplinas atualizada.';

    -- 3. Alunos em risco (depende dos dados atualizados)
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_alunos_em_risco;
    RAISE NOTICE '[Analytics] mv_alunos_em_risco atualizada.';

    RAISE NOTICE '[Analytics] Todas as MVs foram atualizadas com sucesso.';
END;
$$;

COMMENT ON PROCEDURE sp_refresh_todas_mvs() IS
'Atualiza todas as materialized views analíticas de forma sequencial e atómica.
Execução: CALL sp_refresh_todas_mvs();';


-- ═══════════════════════════════════════════════════════════════════════════
-- PROCEDURE: sp_fechar_semestre(p_semestre_descricao VARCHAR)
-- Propósito: Processa o fecho de um semestre lectivo
--
-- Regras de negócio:
--   1. Para todas as matrículas com status 'MATRICULADO' que já possuem
--      nota1 e nota2, calcula a média e define o status final:
--      - Média >= 7.0 → APROVADO
--      - Média < 7.0  → REPROVADO
--   2. Atualiza todas as materialized views analíticas
--   3. Regista a operação no log (via RAISE NOTICE)
--
-- Parâmetro: p_semestre_descricao — apenas para fins de log/identificação
--            (ex: '2026.1'). Como o modelo não tem campo semestre,
--            afeta TODAS as matrículas com status MATRICULADO e notas completas.
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_fechar_semestre(p_semestre_descricao VARCHAR DEFAULT 'N/A')
LANGUAGE plpgsql
AS $$
DECLARE
    v_aprovados INTEGER := 0;
    v_reprovados INTEGER := 0;
    v_total_processados INTEGER := 0;
    MEDIA_APROVACAO CONSTANT NUMERIC := 7.0;
    rec RECORD;
BEGIN
    RAISE NOTICE '[Fecho Semestre %] Iniciando processamento...', p_semestre_descricao;

    -- ─── Processar matrículas com notas completas mas ainda MATRICULADO ───
    FOR rec IN
        SELECT id, nota1, nota2,
               ROUND(((nota1 + nota2) / 2.0)::NUMERIC, 2) AS media
        FROM public.matricula_aluno
        WHERE status = 'MATRICULADO'
          AND nota1 IS NOT NULL
          AND nota2 IS NOT NULL
    LOOP
        v_total_processados := v_total_processados + 1;

        IF rec.media >= MEDIA_APROVACAO THEN
            -- Aprovar o aluno
            UPDATE matricula_aluno
            SET status = 'APROVADO'
            WHERE id = rec.id;
            v_aprovados := v_aprovados + 1;
        ELSE
            -- Reprovar o aluno
            UPDATE matricula_aluno
            SET status = 'REPROVADO'
            WHERE id = rec.id;
            v_reprovados := v_reprovados + 1;
        END IF;
    END LOOP;

    RAISE NOTICE '[Fecho Semestre %] Processadas % matrículas: % aprovados, % reprovados.',
        p_semestre_descricao, v_total_processados, v_aprovados, v_reprovados;

    -- ─── Atualizar todas as materialized views ───────────────────
    RAISE NOTICE '[Fecho Semestre %] Atualizando materialized views...', p_semestre_descricao;
    CALL sp_refresh_todas_mvs();

    RAISE NOTICE '[Fecho Semestre %] Processamento concluído com sucesso.', p_semestre_descricao;

    COMMIT;
END;
$$;

COMMENT ON PROCEDURE sp_fechar_semestre(VARCHAR) IS
'Processa o fecho de semestre: calcula médias finais, define status (APROVADO/REPROVADO)
para matrículas pendentes com notas completas, e atualiza todas as MVs.
Execução: CALL sp_fechar_semestre(''2026.1'');';


-- ═══════════════════════════════════════════════════════════════════════════
-- PROCEDURE: sp_detectar_alunos_risco()
-- Propósito: Pipeline completo de detecção de risco
--
-- Fluxo:
--   1. Refresh de todas as MVs (garante dados atualizados)
--   2. Exibe relatório dos alunos em risco ALTO e CRITICO
--   3. Exibe estatísticas gerais do sistema
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE PROCEDURE sp_detectar_alunos_risco()
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_risco_alto INTEGER;
    v_total_risco_critico INTEGER;
    v_total_alunos INTEGER;
    rec RECORD;
BEGIN
    RAISE NOTICE '═══════════════════════════════════════════════════';
    RAISE NOTICE '    PIPELINE DE DETECÇÃO DE RISCO ACADÉMICO';
    RAISE NOTICE '═══════════════════════════════════════════════════';

    -- 1. Atualizar materialized views
    RAISE NOTICE 'Etapa 1/3: Atualizando dados...';
    CALL sp_refresh_todas_mvs();

    -- 2. Contar alunos por nível de risco
    SELECT COUNT(*) INTO v_total_alunos
    FROM mv_alunos_em_risco;

    SELECT COUNT(*) INTO v_total_risco_alto
    FROM mv_alunos_em_risco WHERE classificacao_risco = 'ALTO';

    SELECT COUNT(*) INTO v_total_risco_critico
    FROM mv_alunos_em_risco WHERE classificacao_risco = 'CRITICO';

    -- 3. Exibir relatório
    RAISE NOTICE '';
    RAISE NOTICE 'Etapa 2/3: Relatório de Risco';
    RAISE NOTICE '───────────────────────────────────────';
    RAISE NOTICE 'Total de alunos analisados: %', v_total_alunos;
    RAISE NOTICE 'Alunos em risco ALTO:       %', v_total_risco_alto;
    RAISE NOTICE 'Alunos em risco CRITICO:    %', v_total_risco_critico;
    RAISE NOTICE '───────────────────────────────────────';

    -- 4. Detalhar alunos em risco CRITICO
    IF v_total_risco_critico > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠  ALUNOS EM RISCO CRITICO:';
        FOR rec IN
            SELECT aluno_nome, aluno_email, score_risco,
                   media_global, qtd_reprovacoes, qtd_trancamentos
            FROM mv_alunos_em_risco
            WHERE classificacao_risco = 'CRITICO'
            ORDER BY score_risco DESC
        LOOP
            RAISE NOTICE '  → % (%) — Score: %, Média: %, Reprov: %, Tranc: %',
                rec.aluno_nome, rec.aluno_email, rec.score_risco,
                COALESCE(rec.media_global::TEXT, 'N/A'),
                rec.qtd_reprovacoes, rec.qtd_trancamentos;
        END LOOP;
    END IF;

    -- 5. Detalhar alunos em risco ALTO
    IF v_total_risco_alto > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '⚠  ALUNOS EM RISCO ALTO:';
        FOR rec IN
            SELECT aluno_nome, aluno_email, score_risco,
                   media_global, qtd_reprovacoes, qtd_trancamentos
            FROM mv_alunos_em_risco
            WHERE classificacao_risco = 'ALTO'
            ORDER BY score_risco DESC
        LOOP
            RAISE NOTICE '  → % (%) — Score: %, Média: %, Reprov: %, Tranc: %',
                rec.aluno_nome, rec.aluno_email, rec.score_risco,
                COALESCE(rec.media_global::TEXT, 'N/A'),
                rec.qtd_reprovacoes, rec.qtd_trancamentos;
        END LOOP;
    END IF;

    RAISE NOTICE '';
    RAISE NOTICE 'Etapa 3/3: Pipeline concluído com sucesso.';
    RAISE NOTICE '═══════════════════════════════════════════════════';

    COMMIT;
END;
$$;

COMMENT ON PROCEDURE sp_detectar_alunos_risco() IS
'Executa o pipeline completo de detecção de risco: refresh das MVs, calcula scores e gera relatório.
Execução: CALL sp_detectar_alunos_risco();';
