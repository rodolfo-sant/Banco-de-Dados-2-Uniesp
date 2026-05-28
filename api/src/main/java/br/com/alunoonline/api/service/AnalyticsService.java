package br.com.alunoonline.api.service;

import br.com.alunoonline.api.dtos.AlunoRiscoDTO;
import br.com.alunoonline.api.dtos.HistoricoAcademicoDTO;
import br.com.alunoonline.api.dtos.PanoramaDisciplinaDTO;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Serviço de Analytics — expõe os dados das materialized views e
 * orquestra a execução das stored procedures do módulo analítico.
 *
 * <p>Usa {@link JdbcTemplate} (em vez de JPA) pois opera directamente
 * sobre objectos de base de dados (MVs, procedures, functions) que não
 * são mapeados como entidades JPA.</p>
 *
 * <p><strong>Fluxo de dados:</strong></p>
 * <pre>
 *   Functions (cálculos) → Materialized Views (consolidação) → API (exposição)
 *   Stored Procedures (orquestração) → Refresh das MVs → Dados actualizados
 * </pre>
 */
@Service
public class AnalyticsService {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    // ═══════════════════════════════════════════════════════════════════
    //  CONSULTAS ÀS MATERIALIZED VIEWS
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Lista todos os alunos com seu score e classificação de risco.
     *
     * <p>Os dados vêm da {@code mv_alunos_em_risco}, que é pré-computada
     * pelas functions {@code fn_score_risco_aluno()} e {@code fn_classificar_risco()}.
     * Ordenados do maior risco para o menor.</p>
     *
     * @return lista de alunos com indicadores de risco
     */
    public List<AlunoRiscoDTO> listarAlunosEmRisco() {
        String sql = """
                SELECT aluno_id, aluno_nome, aluno_email,
                       media_global, qtd_reprovacoes, qtd_trancamentos,
                       qtd_em_curso, score_risco, classificacao_risco,
                       total_matriculas
                FROM mv_alunos_em_risco
                ORDER BY score_risco DESC
                """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AlunoRiscoDTO(
                rs.getLong("aluno_id"),
                rs.getString("aluno_nome"),
                rs.getString("aluno_email"),
                rs.getObject("media_global") != null ? rs.getDouble("media_global") : null,
                rs.getInt("qtd_reprovacoes"),
                rs.getInt("qtd_trancamentos"),
                rs.getInt("qtd_em_curso"),
                rs.getObject("score_risco") != null ? rs.getDouble("score_risco") : null,
                rs.getString("classificacao_risco"),
                rs.getInt("total_matriculas")
        ));
    }

    /**
     * Lista alunos em risco filtrados por classificação.
     *
     * @param classificacao classificação de risco: BAIXO, MODERADO, ALTO, CRITICO
     * @return lista filtrada de alunos em risco
     */
    public List<AlunoRiscoDTO> listarAlunosEmRiscoPorClassificacao(String classificacao) {
        String sql = """
                SELECT aluno_id, aluno_nome, aluno_email,
                       media_global, qtd_reprovacoes, qtd_trancamentos,
                       qtd_em_curso, score_risco, classificacao_risco,
                       total_matriculas
                FROM mv_alunos_em_risco
                WHERE classificacao_risco = ?
                ORDER BY score_risco DESC
                """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new AlunoRiscoDTO(
                rs.getLong("aluno_id"),
                rs.getString("aluno_nome"),
                rs.getString("aluno_email"),
                rs.getObject("media_global") != null ? rs.getDouble("media_global") : null,
                rs.getInt("qtd_reprovacoes"),
                rs.getInt("qtd_trancamentos"),
                rs.getInt("qtd_em_curso"),
                rs.getObject("score_risco") != null ? rs.getDouble("score_risco") : null,
                rs.getString("classificacao_risco"),
                rs.getInt("total_matriculas")
        ), classificacao.toUpperCase());
    }

    /**
     * Retorna o panorama estatístico de todas as disciplinas.
     *
     * <p>Dados da {@code mv_panorama_disciplinas}: métricas agregadas
     * incluindo média da turma, desvio padrão e taxas de aprovação.</p>
     *
     * @return lista de disciplinas com suas estatísticas
     */
    public List<PanoramaDisciplinaDTO> listarPanoramaDisciplinas() {
        String sql = """
                SELECT disciplina_id, disciplina_nome, carga_horaria,
                       professor_nome, total_matriculas, qtd_aprovados,
                       qtd_reprovados, qtd_trancados, media_turma,
                       desvio_padrao, taxa_aprovacao_pct, taxa_reprovacao_pct
                FROM mv_panorama_disciplinas
                ORDER BY disciplina_nome
                """;

        return jdbcTemplate.query(sql, (rs, rowNum) -> new PanoramaDisciplinaDTO(
                rs.getLong("disciplina_id"),
                rs.getString("disciplina_nome"),
                rs.getObject("carga_horaria") != null ? rs.getInt("carga_horaria") : null,
                rs.getString("professor_nome"),
                rs.getInt("total_matriculas"),
                rs.getInt("qtd_aprovados"),
                rs.getInt("qtd_reprovados"),
                rs.getInt("qtd_trancados"),
                rs.getObject("media_turma") != null ? rs.getDouble("media_turma") : null,
                rs.getObject("desvio_padrao") != null ? rs.getDouble("desvio_padrao") : null,
                rs.getObject("taxa_aprovacao_pct") != null ? rs.getDouble("taxa_aprovacao_pct") : null,
                rs.getObject("taxa_reprovacao_pct") != null ? rs.getDouble("taxa_reprovacao_pct") : null
        ));
    }

    /**
     * Retorna o histórico académico consolidado de um aluno específico.
     *
     * <p>Dados da {@code mv_historico_academico_consolidado}.</p>
     *
     * @param alunoId ID do aluno
     * @return histórico académico consolidado, ou null se não encontrado
     */
    public HistoricoAcademicoDTO buscarHistoricoAluno(Long alunoId) {
        String sql = """
                SELECT aluno_id, aluno_nome, aluno_email,
                       total_disciplinas, qtd_aprovadas, qtd_reprovadas,
                       qtd_trancadas, qtd_em_curso, qtd_desligadas,
                       media_global, pct_aprovacao, pct_reprovacao,
                       pct_trancamento
                FROM mv_historico_academico_consolidado
                WHERE aluno_id = ?
                """;

        List<HistoricoAcademicoDTO> resultados = jdbcTemplate.query(sql, (rs, rowNum) -> new HistoricoAcademicoDTO(
                rs.getLong("aluno_id"),
                rs.getString("aluno_nome"),
                rs.getString("aluno_email"),
                rs.getInt("total_disciplinas"),
                rs.getInt("qtd_aprovadas"),
                rs.getInt("qtd_reprovadas"),
                rs.getInt("qtd_trancadas"),
                rs.getInt("qtd_em_curso"),
                rs.getInt("qtd_desligadas"),
                rs.getObject("media_global") != null ? rs.getDouble("media_global") : null,
                rs.getObject("pct_aprovacao") != null ? rs.getDouble("pct_aprovacao") : null,
                rs.getObject("pct_reprovacao") != null ? rs.getDouble("pct_reprovacao") : null,
                rs.getObject("pct_trancamento") != null ? rs.getDouble("pct_trancamento") : null
        ), alunoId);

        return resultados.isEmpty() ? null : resultados.get(0);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  EXECUÇÃO DE STORED PROCEDURES
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Executa o fecho de semestre via stored procedure.
     *
     * <p>Processa todas as matrículas com status MATRICULADO e notas completas:
     * calcula médias, define aprovação/reprovação e atualiza as MVs.</p>
     *
     * @param semestre descrição do semestre para log (ex: "2026.1")
     */
    public void fecharSemestre(String semestre) {
        jdbcTemplate.execute("CALL sp_fechar_semestre('" + semestre + "')");
    }

    /**
     * Executa o pipeline de detecção de risco via stored procedure.
     *
     * <p>Faz refresh de todas as MVs e recalcula os scores de risco.</p>
     */
    public void detectarAlunosEmRisco() {
        jdbcTemplate.execute("CALL sp_detectar_alunos_risco()");
    }

    /**
     * Atualiza manualmente todas as materialized views.
     *
     * <p>Útil quando se quer garantir dados atualizados sem executar
     * o pipeline completo de detecção de risco.</p>
     */
    public void refreshMaterializedViews() {
        jdbcTemplate.execute("CALL sp_refresh_todas_mvs()");
    }
}
