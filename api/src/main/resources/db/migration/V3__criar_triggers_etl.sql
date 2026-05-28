-- ============================================================================
-- MÓDULO 1 — SCRIPT V3: TRIGGERS E FUNCTIONS DE ETL (Sincronização)
-- ============================================================================
-- Base de dados alvo: aluno_online (PRODUÇÃO)
-- Objectivo: Criar triggers que, a cada INSERT/UPDATE nas tabelas de produção,
--            sincronizam automaticamente os dados para a base DW (aluno_online_dw)
--            usando a extensão dblink do PostgreSQL.
--
-- PRÉ-REQUISITOS:
--   1. Extensão dblink instalada: CREATE EXTENSION IF NOT EXISTS dblink;
--   2. Base de dados aluno_online_dw criada e com o Star Schema (V1) aplicado
--   3. Servidor de dblink configurado ou credenciais parametrizadas
--
-- ESTRATÉGIA DE ATUALIZAÇÃO:
--   - SCD Tipo 1 (Slowly Changing Dimension): sobrescreve valores antigos
--   - UPSERT via INSERT ... ON CONFLICT ... DO UPDATE
--   - Dimensões: sincronizadas imediatamente após mudanças na produção
--   - Factos: sincronizados quando matrículas/notas são inseridas ou actualizadas
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- Activar a extensão dblink (necessária para comunicação entre bases)
-- ─────────────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS dblink;

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURAÇÃO: String de conexão ao DW
-- IMPORTANTE: Ajustar host, port, dbname, user e password conforme o ambiente
-- Em produção, considerar usar um Foreign Data Wrapper (FDW) para mais segurança
-- ═══════════════════════════════════════════════════════════════════════════

-- Para facilitar manutenção, definimos a connection string numa função auxiliar
CREATE OR REPLACE FUNCTION fn_dw_connection_string()
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
    -- ╔══════════════════════════════════════════════════════════════╗
    -- ║  AJUSTAR ESTAS CREDENCIAIS CONFORME O SEU AMBIENTE         ║
    -- ║  Em produção, usar variáveis de ambiente ou vault           ║
    -- ╚══════════════════════════════════════════════════════════════╝
    RETURN 'host=localhost port=5432 dbname=aluno_online_dw user=postgres password=postgres';
END;
$$;

COMMENT ON FUNCTION fn_dw_connection_string() IS 'Retorna a string de conexão dblink para a base DW. Centraliza a configuração para facilitar manutenção.';


-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: fn_sync_aluno_to_dw()
-- Dispara: AFTER INSERT OR UPDATE na tabela 'aluno'
-- Acção: Faz UPSERT na dim_aluno da base DW
-- Estratégia: SCD Tipo 1 — sobrescreve dados antigos com os novos
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_sync_aluno_to_dw()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conn_str TEXT;
    v_sql TEXT;
BEGIN
    -- Obter string de conexão centralizada
    v_conn_str := fn_dw_connection_string();

    -- Construir o comando UPSERT para a dim_aluno no DW
    -- ON CONFLICT na chave natural (aluno_id_origem) faz UPDATE (SCD Tipo 1)
    v_sql := format(
        'INSERT INTO dim_aluno (aluno_id_origem, nome_completo, cpf, email, data_carga, data_atualizacao)
         VALUES (%L, %L, %L, %L, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
         ON CONFLICT (aluno_id_origem)
         DO UPDATE SET
             nome_completo    = EXCLUDED.nome_completo,
             cpf              = EXCLUDED.cpf,
             email            = EXCLUDED.email,
             data_atualizacao = CURRENT_TIMESTAMP',
        NEW.id,
        NEW.nome_completo,
        NEW.cpf,
        NEW.email
    );

    -- Executar o comando no DW via dblink
    -- PERFORM descarta o resultado (não precisamos do retorno)
    PERFORM dblink_exec(v_conn_str, v_sql);

    RETURN NEW;

EXCEPTION
    -- Em caso de erro na sincronização, apenas logar (não bloquear a transação de produção)
    WHEN OTHERS THEN
        RAISE WARNING '[ETL] Falha ao sincronizar aluno id=% para DW: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_sync_aluno_to_dw() IS 'Trigger function: sincroniza dados do aluno para dim_aluno no DW via dblink (UPSERT, SCD Tipo 1).';

-- Criar o trigger na tabela aluno
DROP TRIGGER IF EXISTS trg_sync_aluno_dw ON aluno;
CREATE TRIGGER trg_sync_aluno_dw
    AFTER INSERT OR UPDATE ON aluno
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_aluno_to_dw();

COMMENT ON TRIGGER trg_sync_aluno_dw ON aluno IS 'Trigger ETL: sincroniza automaticamente inserções e atualizações de alunos para a dim_aluno no DW.';


-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: fn_sync_professor_to_dw()
-- Dispara: AFTER INSERT OR UPDATE na tabela 'professor'
-- Acção: UPSERT na dim_professor do DW
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_sync_professor_to_dw()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conn_str TEXT;
    v_sql TEXT;
BEGIN
    v_conn_str := fn_dw_connection_string();

    v_sql := format(
        'INSERT INTO dim_professor (professor_id_origem, nome, email, cpf, data_carga, data_atualizacao)
         VALUES (%L, %L, %L, %L, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
         ON CONFLICT (professor_id_origem)
         DO UPDATE SET
             nome             = EXCLUDED.nome,
             email            = EXCLUDED.email,
             cpf              = EXCLUDED.cpf,
             data_atualizacao = CURRENT_TIMESTAMP',
        NEW.id,
        NEW.nome,
        NEW.email,
        NEW.cpf
    );

    PERFORM dblink_exec(v_conn_str, v_sql);
    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[ETL] Falha ao sincronizar professor id=% para DW: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_professor_dw ON professor;
CREATE TRIGGER trg_sync_professor_dw
    AFTER INSERT OR UPDATE ON professor
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_professor_to_dw();


-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: fn_sync_disciplina_to_dw()
-- Dispara: AFTER INSERT OR UPDATE na tabela 'disciplina'
-- Acção: UPSERT na dim_disciplina do DW (inclui nome do professor desnormalizado)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_sync_disciplina_to_dw()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conn_str TEXT;
    v_sql TEXT;
    v_professor_nome VARCHAR(255);
BEGIN
    v_conn_str := fn_dw_connection_string();

    -- Buscar nome do professor associado à disciplina (pode ser NULL)
    IF NEW.professor_id IS NOT NULL THEN
        SELECT nome INTO v_professor_nome
        FROM professor
        WHERE id = NEW.professor_id;
    ELSE
        v_professor_nome := NULL;
    END IF;

    v_sql := format(
        'INSERT INTO dim_disciplina (disciplina_id_origem, nome, carga_horaria, professor_id_origem, professor_nome, data_carga, data_atualizacao)
         VALUES (%L, %L, %L, %L, %L, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
         ON CONFLICT (disciplina_id_origem)
         DO UPDATE SET
             nome                = EXCLUDED.nome,
             carga_horaria       = EXCLUDED.carga_horaria,
             professor_id_origem = EXCLUDED.professor_id_origem,
             professor_nome      = EXCLUDED.professor_nome,
             data_atualizacao    = CURRENT_TIMESTAMP',
        NEW.id,
        NEW.nome,
        NEW.carga_horaria,
        NEW.professor_id,
        v_professor_nome
    );

    PERFORM dblink_exec(v_conn_str, v_sql);
    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[ETL] Falha ao sincronizar disciplina id=% para DW: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_disciplina_dw ON disciplina;
CREATE TRIGGER trg_sync_disciplina_dw
    AFTER INSERT OR UPDATE ON disciplina
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_disciplina_to_dw();


-- ═══════════════════════════════════════════════════════════════════════════
-- TRIGGER FUNCTION: fn_sync_matricula_to_dw()
-- Dispara: AFTER INSERT OR UPDATE na tabela 'matricula_aluno'
-- Acção: UPSERT na fato_desempenho do DW
--
-- Esta é a função mais complexa, pois precisa:
--   1. Resolver as surrogate keys das dimensões no DW
--   2. Calcular a média das notas
--   3. Determinar a flag de aprovação
--   4. Associar uma data da dim_tempo (usa CURRENT_DATE)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_sync_matricula_to_dw()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_conn_str TEXT;
    v_sql TEXT;
    v_media NUMERIC(5,2);
    v_aprovado_flag SMALLINT;
BEGIN
    v_conn_str := fn_dw_connection_string();

    -- Calcular a média (NULL se alguma nota estiver ausente)
    IF NEW.nota1 IS NOT NULL AND NEW.nota2 IS NOT NULL THEN
        v_media := ROUND(((NEW.nota1 + NEW.nota2) / 2.0)::NUMERIC, 2);
    ELSE
        v_media := NULL;
    END IF;

    -- Determinar flag de aprovação
    IF NEW.status = 'APROVADO' THEN
        v_aprovado_flag := 1;
    ELSE
        v_aprovado_flag := 0;
    END IF;

    -- ─────────────────────────────────────────────────────────────────
    -- O UPSERT na fato_desempenho precisa resolver as surrogate keys
    -- das dimensões. Usamos subqueries executadas no contexto do DW.
    -- ─────────────────────────────────────────────────────────────────
    v_sql := format(
        'INSERT INTO fato_desempenho (
            matricula_id_origem,
            dim_aluno_id,
            dim_disciplina_id,
            dim_tempo_id,
            nota1, nota2, media, status, aprovado_flag,
            data_carga, data_atualizacao
        )
        VALUES (
            %L,
            (SELECT dim_aluno_id FROM dim_aluno WHERE aluno_id_origem = %L),
            (SELECT dim_disciplina_id FROM dim_disciplina WHERE disciplina_id_origem = %L),
            (SELECT dim_tempo_id FROM dim_tempo WHERE data_completa = CURRENT_DATE),
            %L, %L, %L, %L, %L,
            CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        )
        ON CONFLICT (matricula_id_origem)
        DO UPDATE SET
            nota1            = EXCLUDED.nota1,
            nota2            = EXCLUDED.nota2,
            media            = EXCLUDED.media,
            status           = EXCLUDED.status,
            aprovado_flag    = EXCLUDED.aprovado_flag,
            data_atualizacao = CURRENT_TIMESTAMP',
        NEW.id,
        NEW.aluno_id,
        NEW.disciplina_id,
        NEW.nota1,
        NEW.nota2,
        v_media,
        NEW.status,
        v_aprovado_flag
    );

    PERFORM dblink_exec(v_conn_str, v_sql);
    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING '[ETL] Falha ao sincronizar matricula id=% para DW: %', NEW.id, SQLERRM;
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_sync_matricula_to_dw() IS
'Trigger function ETL: sincroniza matrículas para fato_desempenho no DW.
Resolve surrogate keys das dimensões via subqueries, calcula média e flag de aprovação.
Em caso de UPDATE (ex: atualização de notas), faz UPSERT para recalcular métricas.';

DROP TRIGGER IF EXISTS trg_sync_matricula_dw ON matricula_aluno;
CREATE TRIGGER trg_sync_matricula_dw
    AFTER INSERT OR UPDATE ON matricula_aluno
    FOR EACH ROW
    EXECUTE FUNCTION fn_sync_matricula_to_dw();

COMMENT ON TRIGGER trg_sync_matricula_dw ON matricula_aluno IS 'Trigger ETL: sincroniza inserções e atualizações de matrículas/notas para fato_desempenho no DW.';


-- ═══════════════════════════════════════════════════════════════════════════
-- FUNÇÃO AUXILIAR: fn_carga_inicial_dw()
-- Propósito: Executar carga inicial completa dos dados existentes para o DW
-- Útil para: Primeira execução ou reconstrução do DW após reset
-- Execução: SELECT fn_carga_inicial_dw();
-- ═══════════════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION fn_carga_inicial_dw()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_conn_str TEXT;
    v_count_alunos INTEGER;
    v_count_prof INTEGER;
    v_count_disc INTEGER;
    v_count_mat INTEGER;
BEGIN
    v_conn_str := fn_dw_connection_string();

    -- ─── Carga de Alunos ─────────────────────────────────────────
    PERFORM dblink_exec(v_conn_str,
        'INSERT INTO dim_aluno (aluno_id_origem, nome_completo, cpf, email)
         SELECT aluno_id, nome_completo, cpf, email
         FROM dblink(''' || v_conn_str || ''',
             ''SELECT id, nome_completo, cpf, email FROM aluno'')
         AS t(aluno_id BIGINT, nome_completo VARCHAR, cpf VARCHAR, email VARCHAR)
         ON CONFLICT (aluno_id_origem) DO NOTHING'
    );

    -- Alternativa mais simples: usar a view local e dblink para inserir
    FOR v_count_alunos IN
        SELECT count(*) FROM aluno
    LOOP NULL; END LOOP;

    -- ─── Carga de Professores ────────────────────────────────────
    PERFORM dblink_exec(v_conn_str, (
        SELECT string_agg(
            format(
                'INSERT INTO dim_professor (professor_id_origem, nome, email, cpf)
                 VALUES (%L, %L, %L, %L)
                 ON CONFLICT (professor_id_origem) DO NOTHING',
                p.id, p.nome, p.email, p.cpf
            ), '; '
        )
        FROM professor p
    ));

    -- ─── Carga de Disciplinas ────────────────────────────────────
    PERFORM dblink_exec(v_conn_str, (
        SELECT string_agg(
            format(
                'INSERT INTO dim_disciplina (disciplina_id_origem, nome, carga_horaria, professor_id_origem, professor_nome)
                 VALUES (%L, %L, %L, %L, %L)
                 ON CONFLICT (disciplina_id_origem) DO NOTHING',
                v.disciplina_id, v.nome, v.carga_horaria, v.professor_id, v.professor_nome
            ), '; '
        )
        FROM vw_disciplina_para_dw v
    ));

    -- ─── Carga de Matrículas (Factos) ────────────────────────────
    PERFORM dblink_exec(v_conn_str, (
        SELECT string_agg(
            format(
                'INSERT INTO fato_desempenho (matricula_id_origem, dim_aluno_id, dim_disciplina_id, dim_tempo_id, nota1, nota2, media, status, aprovado_flag)
                 VALUES (%L,
                     (SELECT dim_aluno_id FROM dim_aluno WHERE aluno_id_origem = %L),
                     (SELECT dim_disciplina_id FROM dim_disciplina WHERE disciplina_id_origem = %L),
                     (SELECT dim_tempo_id FROM dim_tempo WHERE data_completa = CURRENT_DATE),
                     %L, %L, %L, %L, %L)
                 ON CONFLICT (matricula_id_origem) DO NOTHING',
                v.matricula_id, v.aluno_id, v.disciplina_id,
                v.nota1, v.nota2, v.media, v.status, v.aprovado_flag
            ), '; '
        )
        FROM vw_matricula_completa v
    ));

    RETURN format('Carga inicial concluída. Dados sincronizados para o DW.');

EXCEPTION
    WHEN OTHERS THEN
        RETURN format('Erro na carga inicial: %s', SQLERRM);
END;
$$;

COMMENT ON FUNCTION fn_carga_inicial_dw() IS
'Executa carga inicial completa de todas as tabelas de produção para o DW.
Usar após criar o DW pela primeira vez ou após reset. Execução: SELECT fn_carga_inicial_dw();';
