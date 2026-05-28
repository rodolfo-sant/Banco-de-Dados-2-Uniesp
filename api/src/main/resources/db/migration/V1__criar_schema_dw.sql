-- ============================================================================
-- MÓDULO 1 — SCRIPT V1: CRIAÇÃO DO STAR SCHEMA (Base de Homologação / DW)
-- ============================================================================
-- Base de dados alvo: aluno_online_dw
-- Objectivo: Modelagem dimensional para análise de desempenho académico
-- Esquema: Star Schema com 4 dimensões + 1 tabela de factos
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- DIMENSÃO: dim_aluno
-- Armazena os dados descritivos dos alunos (SCD Tipo 1 — sobrescreve)
-- Surrogate Key: dim_aluno_id | Natural Key: aluno_id_origem
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS dim_aluno (
    dim_aluno_id    BIGSERIAL       PRIMARY KEY,
    aluno_id_origem BIGINT          NOT NULL UNIQUE,  -- FK lógica para produção
    nome_completo   VARCHAR(255)    NOT NULL,
    cpf             VARCHAR(14),
    email           VARCHAR(255),
    data_carga      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índice para lookups rápidos pela chave natural (usado pelos triggers)
CREATE INDEX IF NOT EXISTS idx_dim_aluno_origem ON dim_aluno(aluno_id_origem);

COMMENT ON TABLE dim_aluno IS 'Dimensão Aluno — contém dados descritivos dos alunos, sincronizados desde a base de produção via trigger (SCD Tipo 1).';
COMMENT ON COLUMN dim_aluno.aluno_id_origem IS 'Chave natural: ID do aluno na base de produção (tabela aluno.id).';


-- ═══════════════════════════════════════════════════════════════════════════
-- DIMENSÃO: dim_professor
-- Dados descritivos dos professores (SCD Tipo 1)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS dim_professor (
    dim_professor_id    BIGSERIAL       PRIMARY KEY,
    professor_id_origem BIGINT          NOT NULL UNIQUE,
    nome                VARCHAR(255)    NOT NULL,
    email               VARCHAR(255),
    cpf                 VARCHAR(14),
    data_carga          TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dim_professor_origem ON dim_professor(professor_id_origem);

COMMENT ON TABLE dim_professor IS 'Dimensão Professor — dados descritivos dos professores, SCD Tipo 1.';


-- ═══════════════════════════════════════════════════════════════════════════
-- DIMENSÃO: dim_disciplina
-- Dados descritivos das disciplinas com professor desnormalizado
-- Desnormalização intencional: nome do professor incluído para facilitar
-- consultas analíticas sem necessidade de JOIN adicional
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS dim_disciplina (
    dim_disciplina_id       BIGSERIAL       PRIMARY KEY,
    disciplina_id_origem    BIGINT          NOT NULL UNIQUE,
    nome                    VARCHAR(255)    NOT NULL,
    carga_horaria           INTEGER,
    professor_id_origem     BIGINT,                         -- FK lógica
    professor_nome          VARCHAR(255),                   -- Desnormalizado
    data_carga              TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao        TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dim_disciplina_origem ON dim_disciplina(disciplina_id_origem);

COMMENT ON TABLE dim_disciplina IS 'Dimensão Disciplina — inclui nome do professor desnormalizado para facilitar queries OLAP.';
COMMENT ON COLUMN dim_disciplina.professor_nome IS 'Nome do professor desnormalizado desde dim_professor para evitar JOINs em consultas analíticas.';


-- ═══════════════════════════════════════════════════════════════════════════
-- DIMENSÃO: dim_tempo
-- Dimensão temporal pré-populada para o período 2020-2030
-- Permite análise por ano, semestre, trimestre e mês
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS dim_tempo (
    dim_tempo_id    BIGSERIAL   PRIMARY KEY,
    data_completa   DATE        NOT NULL UNIQUE,
    ano             INTEGER     NOT NULL,
    semestre        INTEGER     NOT NULL,   -- 1 ou 2
    trimestre       INTEGER     NOT NULL,   -- 1 a 4
    mes             INTEGER     NOT NULL,   -- 1 a 12
    nome_mes        VARCHAR(20) NOT NULL,
    dia             INTEGER     NOT NULL,
    dia_semana      VARCHAR(20) NOT NULL,
    semana_ano      INTEGER     NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_dim_tempo_ano ON dim_tempo(ano);
CREATE INDEX IF NOT EXISTS idx_dim_tempo_ano_sem ON dim_tempo(ano, semestre);

COMMENT ON TABLE dim_tempo IS 'Dimensão Tempo — pré-populada de 2020 a 2030. Permite análise temporal por ano, semestre, trimestre, mês.';

-- ─────────────────────────────────────────────────────────────────────────
-- Pré-população da dim_tempo (2020-01-01 até 2030-12-31)
-- Usa generate_series para criar uma entrada por dia
-- ─────────────────────────────────────────────────────────────────────────
INSERT INTO dim_tempo (data_completa, ano, semestre, trimestre, mes, nome_mes, dia, dia_semana, semana_ano)
SELECT
    d::DATE                                         AS data_completa,
    EXTRACT(YEAR FROM d)::INTEGER                   AS ano,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END AS semestre,
    EXTRACT(QUARTER FROM d)::INTEGER                AS trimestre,
    EXTRACT(MONTH FROM d)::INTEGER                  AS mes,
    TO_CHAR(d, 'TMMonth')                           AS nome_mes,     -- Nome do mês em português (depende do locale)
    EXTRACT(DAY FROM d)::INTEGER                    AS dia,
    TO_CHAR(d, 'TMDay')                             AS dia_semana,
    EXTRACT(WEEK FROM d)::INTEGER                   AS semana_ano
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, '1 day'::INTERVAL) AS d
ON CONFLICT (data_completa) DO NOTHING;


-- ═══════════════════════════════════════════════════════════════════════════
-- TABELA DE FACTOS: fato_desempenho
-- Granularidade: uma linha por matrícula (aluno × disciplina)
-- Métricas: nota1, nota2, média calculada, flag de aprovação
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS fato_desempenho (
    fato_id                 BIGSERIAL   PRIMARY KEY,
    matricula_id_origem     BIGINT      NOT NULL UNIQUE,    -- NK: id da matricula_aluno na produção

    -- Chaves estrangeiras para as dimensões (surrogate keys)
    dim_aluno_id            BIGINT      NOT NULL REFERENCES dim_aluno(dim_aluno_id),
    dim_disciplina_id       BIGINT      NOT NULL REFERENCES dim_disciplina(dim_disciplina_id),
    dim_tempo_id            BIGINT      REFERENCES dim_tempo(dim_tempo_id),  -- Nullable: data pode não estar disponível

    -- Métricas / Medidas
    nota1                   NUMERIC(5,2),
    nota2                   NUMERIC(5,2),
    media                   NUMERIC(5,2),                   -- Calculada: (nota1 + nota2) / 2
    status                  VARCHAR(20),                    -- MATRICULADO, APROVADO, REPROVADO, TRANCADO, DESLIGADO
    aprovado_flag           SMALLINT    DEFAULT 0,          -- 1 = aprovado, 0 = não aprovado (facilita SUM/COUNT)

    -- Metadados de carga
    data_carga              TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    data_atualizacao        TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices para queries analíticas frequentes
CREATE INDEX IF NOT EXISTS idx_fato_aluno ON fato_desempenho(dim_aluno_id);
CREATE INDEX IF NOT EXISTS idx_fato_disciplina ON fato_desempenho(dim_disciplina_id);
CREATE INDEX IF NOT EXISTS idx_fato_tempo ON fato_desempenho(dim_tempo_id);
CREATE INDEX IF NOT EXISTS idx_fato_status ON fato_desempenho(status);
CREATE INDEX IF NOT EXISTS idx_fato_matricula_origem ON fato_desempenho(matricula_id_origem);

COMMENT ON TABLE fato_desempenho IS 'Tabela de Factos — regista o desempenho académico por matrícula. Granularidade: 1 linha = 1 matrícula (aluno × disciplina).';
COMMENT ON COLUMN fato_desempenho.media IS 'Média aritmética calculada: (nota1 + nota2) / 2. Null se alguma das notas for null.';
COMMENT ON COLUMN fato_desempenho.aprovado_flag IS 'Flag binária para facilitar agregações: 1 = aprovado, 0 = não aprovado.';
