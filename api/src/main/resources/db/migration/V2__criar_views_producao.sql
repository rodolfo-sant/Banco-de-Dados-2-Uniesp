-- ============================================================================
-- MÓDULO 1 — SCRIPT V2: VIEWS NA BASE DE PRODUÇÃO
-- ============================================================================
-- Base de dados alvo: aluno_online (PRODUÇÃO)
-- Objectivo: Consolidar dados das tabelas transacionais em views que
--            facilitam o processo de ETL para o Data Warehouse.
--            Estas views servem como camada de abstração entre o modelo
--            OLTP e o modelo dimensional OLAP.
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- VIEW: vw_aluno_para_dw
-- Propósito: Seleciona os dados do aluno no formato esperado pela dim_aluno
-- Utilização: Usada pela função de trigger para popular dim_aluno no DW
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_aluno_para_dw AS
SELECT
    a.id                AS aluno_id,
    a.nome_completo     AS nome_completo,
    a.cpf               AS cpf,
    a.email             AS email,
    CURRENT_TIMESTAMP   AS data_extracao
FROM aluno a;

COMMENT ON VIEW vw_aluno_para_dw IS 'View de extração: mapeia os campos da tabela aluno para o formato da dim_aluno no DW.';


-- ═══════════════════════════════════════════════════════════════════════════
-- VIEW: vw_professor_para_dw
-- Propósito: Dados do professor prontos para sincronização com dim_professor
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_professor_para_dw AS
SELECT
    p.id                AS professor_id,
    p.nome              AS nome,
    p.email             AS email,
    p.cpf               AS cpf,
    CURRENT_TIMESTAMP   AS data_extracao
FROM professor p;

COMMENT ON VIEW vw_professor_para_dw IS 'View de extração: mapeia campos da tabela professor para o formato da dim_professor no DW.';


-- ═══════════════════════════════════════════════════════════════════════════
-- VIEW: vw_disciplina_para_dw
-- Propósito: Desnormaliza disciplina + professor para dim_disciplina
-- Nota: LEFT JOIN garante que disciplinas sem professor atribuído também
--       sejam extraídas (professor_nome ficará NULL)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_disciplina_para_dw AS
SELECT
    d.id                AS disciplina_id,
    d.nome              AS nome,
    d.carga_horaria     AS carga_horaria,
    d.professor_id      AS professor_id,
    p.nome              AS professor_nome,    -- Desnormalizado
    CURRENT_TIMESTAMP   AS data_extracao
FROM disciplina d
LEFT JOIN professor p ON p.id = d.professor_id;

COMMENT ON VIEW vw_disciplina_para_dw IS 'View de extração: combina disciplina e professor (desnormalizado) para popular dim_disciplina no DW.';


-- ═══════════════════════════════════════════════════════════════════════════
-- VIEW: vw_matricula_completa
-- Propósito: Visão unificada de toda a matrícula com dados relacionados
-- Inclui: dados do aluno, disciplina, professor, notas e média calculada
-- Esta view é útil tanto para ETL quanto para relatórios da API
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_matricula_completa AS
SELECT
    -- Identificadores
    ma.id               AS matricula_id,
    ma.aluno_id         AS aluno_id,
    ma.disciplina_id    AS disciplina_id,

    -- Dados do Aluno
    a.nome_completo     AS aluno_nome,
    a.email             AS aluno_email,
    a.cpf               AS aluno_cpf,

    -- Dados da Disciplina
    d.nome              AS disciplina_nome,
    d.carga_horaria     AS disciplina_carga_horaria,

    -- Dados do Professor
    p.id                AS professor_id,
    p.nome              AS professor_nome,

    -- Notas e Desempenho
    ma.nota1            AS nota1,
    ma.nota2            AS nota2,
    CASE
        WHEN ma.nota1 IS NOT NULL AND ma.nota2 IS NOT NULL
            THEN ROUND(((ma.nota1 + ma.nota2) / 2.0)::NUMERIC, 2)
        ELSE NULL
    END                 AS media,
    ma.status           AS status,

    -- Flag de aprovação para agregações rápidas
    CASE
        WHEN ma.status = 'APROVADO' THEN 1
        ELSE 0
    END                 AS aprovado_flag,

    -- Metadado temporal (usa a data corrente como referência)
    CURRENT_DATE        AS data_referencia

FROM matricula_aluno ma
INNER JOIN aluno a       ON a.id = ma.aluno_id
INNER JOIN disciplina d  ON d.id = ma.disciplina_id
LEFT  JOIN professor p   ON p.id = d.professor_id;

COMMENT ON VIEW vw_matricula_completa IS 'View consolidada: junta matrícula + aluno + disciplina + professor com média calculada. Usada para ETL e relatórios.';


-- ═══════════════════════════════════════════════════════════════════════════
-- VIEW: vw_desempenho_por_disciplina
-- Propósito: Agregação do desempenho por disciplina (útil para dashboards)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW vw_desempenho_por_disciplina AS
SELECT
    d.id                                    AS disciplina_id,
    d.nome                                  AS disciplina_nome,
    p.nome                                  AS professor_nome,
    COUNT(ma.id)                            AS total_matriculas,
    COUNT(CASE WHEN ma.status = 'APROVADO'    THEN 1 END) AS total_aprovados,
    COUNT(CASE WHEN ma.status = 'REPROVADO'   THEN 1 END) AS total_reprovados,
    COUNT(CASE WHEN ma.status = 'TRANCADO'    THEN 1 END) AS total_trancados,
    COUNT(CASE WHEN ma.status = 'MATRICULADO' THEN 1 END) AS total_em_curso,
    ROUND(AVG(
        CASE
            WHEN ma.nota1 IS NOT NULL AND ma.nota2 IS NOT NULL
                THEN (ma.nota1 + ma.nota2) / 2.0
            ELSE NULL
        END
    )::NUMERIC, 2)                          AS media_turma,
    ROUND((
        COUNT(CASE WHEN ma.status = 'APROVADO' THEN 1 END)::NUMERIC /
        NULLIF(COUNT(CASE WHEN ma.status IN ('APROVADO', 'REPROVADO') THEN 1 END), 0)
        * 100
    )::NUMERIC, 2)                          AS taxa_aprovacao_pct
FROM disciplina d
LEFT JOIN professor p       ON p.id = d.professor_id
LEFT JOIN matricula_aluno ma ON ma.disciplina_id = d.id
GROUP BY d.id, d.nome, p.nome;

COMMENT ON VIEW vw_desempenho_por_disciplina IS 'View analítica: métricas agregadas por disciplina — total matriculados, aprovados, reprovados, média e taxa de aprovação.';
