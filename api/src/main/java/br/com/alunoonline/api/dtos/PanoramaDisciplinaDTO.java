package br.com.alunoonline.api.dtos;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO para representar o panorama estatístico de uma disciplina.
 *
 * <p>Mapeado a partir da materialized view {@code mv_panorama_disciplinas}.
 * Contém métricas agregadas que permitem à equipa académica avaliar
 * o desempenho por disciplina.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class PanoramaDisciplinaDTO {

    /** ID da disciplina */
    private Long disciplinaId;

    /** Nome da disciplina */
    private String disciplinaNome;

    /** Carga horária da disciplina */
    private Integer cargaHoraria;

    /** Nome do professor responsável */
    private String professorNome;

    /** Total de alunos matriculados (todas as matrículas) */
    private Integer totalMatriculas;

    /** Quantidade de alunos aprovados */
    private Integer qtdAprovados;

    /** Quantidade de alunos reprovados */
    private Integer qtdReprovados;

    /** Quantidade de alunos que trancaram */
    private Integer qtdTrancados;

    /** Média aritmética de notas da turma */
    private Double mediaTurma;

    /** Desvio padrão das notas (dispersão) */
    private Double desvioPadrao;

    /** Taxa de aprovação em percentagem */
    private Double taxaAprovacaoPct;

    /** Taxa de reprovação em percentagem */
    private Double taxaReprovacaoPct;
}
