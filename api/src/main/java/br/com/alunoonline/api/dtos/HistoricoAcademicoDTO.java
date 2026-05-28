package br.com.alunoonline.api.dtos;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO para representar o histórico académico consolidado de um aluno.
 *
 * <p>Mapeado a partir da materialized view {@code mv_historico_academico_consolidado}.
 * Fornece uma visão completa do percurso académico do aluno.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class HistoricoAcademicoDTO {

    /** ID do aluno */
    private Long alunoId;

    /** Nome completo do aluno */
    private String alunoNome;

    /** Email do aluno */
    private String alunoEmail;

    /** Total de disciplinas (todas as matrículas) */
    private Integer totalDisciplinas;

    /** Quantidade de disciplinas aprovadas */
    private Integer qtdAprovadas;

    /** Quantidade de disciplinas reprovadas */
    private Integer qtdReprovadas;

    /** Quantidade de disciplinas trancadas */
    private Integer qtdTrancadas;

    /** Quantidade de disciplinas em curso (MATRICULADO) */
    private Integer qtdEmCurso;

    /** Quantidade de disciplinas com status DESLIGADO */
    private Integer qtdDesligadas;

    /** Média global do aluno */
    private Double mediaGlobal;

    /** Percentagem de aprovação */
    private Double pctAprovacao;

    /** Percentagem de reprovação */
    private Double pctReprovacao;

    /** Percentagem de trancamento */
    private Double pctTrancamento;
}
