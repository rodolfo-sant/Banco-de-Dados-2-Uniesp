package br.com.alunoonline.api.controller;

import br.com.alunoonline.api.dtos.AlunoRiscoDTO;
import br.com.alunoonline.api.dtos.HistoricoAcademicoDTO;
import br.com.alunoonline.api.dtos.PanoramaDisciplinaDTO;
import br.com.alunoonline.api.service.AnalyticsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * Controller REST para o módulo de Analytics e Detecção de Risco.
 *
 * <p>Expõe os dados analíticos das materialized views e permite
 * disparar stored procedures de processamento.</p>
 *
 * <p><strong>Endpoints de Consulta (GET):</strong></p>
 * <ul>
 *   <li>{@code /analytics/alunos-risco} — Lista todos os alunos com score de risco</li>
 *   <li>{@code /analytics/panorama-disciplinas} — Estatísticas por disciplina</li>
 *   <li>{@code /analytics/historico/{alunoId}} — Histórico consolidado de um aluno</li>
 * </ul>
 *
 * <p><strong>Endpoints de Processamento (POST):</strong></p>
 * <ul>
 *   <li>{@code /analytics/fechar-semestre/{semestre}} — Dispara fecho de semestre</li>
 *   <li>{@code /analytics/detectar-risco} — Dispara pipeline de detecção de risco</li>
 *   <li>{@code /analytics/refresh-views} — Atualiza as materialized views</li>
 * </ul>
 */
@RestController
@RequestMapping("/analytics")
public class AnalyticsController {

    @Autowired
    private AnalyticsService analyticsService;

    // ═══════════════════════════════════════════════════════════════════
    //  ENDPOINTS DE CONSULTA (LEITURA)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Lista todos os alunos com score e classificação de risco.
     * Opcionalmente filtra por classificação de risco.
     *
     * <p>Exemplos:</p>
     * <pre>
     * GET /analytics/alunos-risco                         — Todos
     * GET /analytics/alunos-risco?classificacao=CRITICO   — Apenas críticos
     * GET /analytics/alunos-risco?classificacao=ALTO      — Apenas alto risco
     * </pre>
     *
     * @param classificacao filtro opcional: BAIXO, MODERADO, ALTO, CRITICO
     * @return lista de alunos com indicadores de risco
     */
    @GetMapping("/alunos-risco")
    @ResponseStatus(HttpStatus.OK)
    public List<AlunoRiscoDTO> listarAlunosEmRisco(
            @RequestParam(required = false) String classificacao) {

        if (classificacao != null && !classificacao.isBlank()) {
            return analyticsService.listarAlunosEmRiscoPorClassificacao(classificacao);
        }
        return analyticsService.listarAlunosEmRisco();
    }

    /**
     * Retorna o panorama estatístico de todas as disciplinas.
     * Inclui: média da turma, desvio padrão, taxas de aprovação e reprovação.
     *
     * @return lista de disciplinas com estatísticas agregadas
     */
    @GetMapping("/panorama-disciplinas")
    @ResponseStatus(HttpStatus.OK)
    public List<PanoramaDisciplinaDTO> listarPanoramaDisciplinas() {
        return analyticsService.listarPanoramaDisciplinas();
    }

    /**
     * Retorna o histórico académico consolidado de um aluno específico.
     *
     * @param alunoId ID do aluno a consultar
     * @return histórico consolidado ou 404 se não encontrado
     */
    @GetMapping("/historico/{alunoId}")
    public ResponseEntity<HistoricoAcademicoDTO> buscarHistoricoAluno(
            @PathVariable Long alunoId) {

        HistoricoAcademicoDTO historico = analyticsService.buscarHistoricoAluno(alunoId);

        if (historico == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(historico);
    }

    // ═══════════════════════════════════════════════════════════════════
    //  ENDPOINTS DE PROCESSAMENTO (ESCRITA)
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Dispara o fecho de semestre via stored procedure.
     *
     * <p>Processa todas as matrículas com status MATRICULADO que possuem
     * notas completas: calcula médias finais, define aprovação/reprovação
     * e atualiza as materialized views.</p>
     *
     * @param semestre identificação do semestre (ex: "2026.1")
     * @return mensagem de confirmação
     */
    @PostMapping("/fechar-semestre/{semestre}")
    public ResponseEntity<Map<String, String>> fecharSemestre(
            @PathVariable String semestre) {

        analyticsService.fecharSemestre(semestre);

        return ResponseEntity.ok(Map.of(
                "mensagem", "Semestre " + semestre + " fechado com sucesso.",
                "semestre", semestre,
                "status", "CONCLUIDO"
        ));
    }

    /**
     * Dispara o pipeline completo de detecção de risco.
     *
     * <p>Faz refresh de todas as materialized views e recalcula os scores
     * de risco de todos os alunos.</p>
     *
     * @return mensagem de confirmação
     */
    @PostMapping("/detectar-risco")
    public ResponseEntity<Map<String, String>> detectarAlunosEmRisco() {
        analyticsService.detectarAlunosEmRisco();

        return ResponseEntity.ok(Map.of(
                "mensagem", "Pipeline de detecção de risco executado com sucesso.",
                "status", "CONCLUIDO"
        ));
    }

    /**
     * Atualiza manualmente todas as materialized views analíticas.
     *
     * <p>Útil para garantir dados atualizados antes de uma consulta
     * sem executar o pipeline completo de detecção de risco.</p>
     *
     * @return mensagem de confirmação
     */
    @PostMapping("/refresh-views")
    public ResponseEntity<Map<String, String>> refreshViews() {
        analyticsService.refreshMaterializedViews();

        return ResponseEntity.ok(Map.of(
                "mensagem", "Materialized views atualizadas com sucesso.",
                "status", "CONCLUIDO"
        ));
    }
}
