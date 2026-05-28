package br.com.alunoonline.api.dtos;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO para representar um aluno com seu score e classificação de risco.
 *
 * <p>Mapeado a partir da materialized view {@code mv_alunos_em_risco} no PostgreSQL.
 * O score é calculado pela function {@code fn_score_risco_aluno()} com pesos:</p>
 * <ul>
 *   <li>35% — Percentagem de reprovações</li>
 *   <li>30% — Penalidade por média baixa</li>
 *   <li>20% — Percentagem de trancamentos</li>
 *   <li>15% — Desvio negativo em relação à média do sistema</li>
 * </ul>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class AlunoRiscoDTO {

    /** ID do aluno na base de produção */
    private Long alunoId;

    /** Nome completo do aluno */
    private String alunoNome;

    /** Email do aluno */
    private String alunoEmail;

    /** Média global do aluno em todas as disciplinas */
    private Double mediaGlobal;

    /** Quantidade de reprovações */
    private Integer qtdReprovacoes;

    /** Quantidade de trancamentos */
    private Integer qtdTrancamentos;

    /** Quantidade de disciplinas em curso (MATRICULADO) */
    private Integer qtdEmCurso;

    /** Score de risco calculado (0 = sem risco, 100 = risco máximo) */
    private Double scoreRisco;

    /** Classificação textual: BAIXO, MODERADO, ALTO ou CRITICO */
    private String classificacaoRisco;

    /** Total de matrículas do aluno (para contexto) */
    private Integer totalMatriculas;
}
