package br.com.alunoonline.api.dtos;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO de resposta para os relatórios dinâmicos de matrículas.
 *
 * <p>Contém os campos mais relevantes de cada matrícula, consolidados
 * a partir do JOIN entre aluno, disciplina e matrícula. A média é
 * calculada no serviço para evitar inconsistências.</p>
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class RelatorioResponseDTO {

    /** Nome completo do aluno */
    private String nomeAluno;

    /** Email do aluno */
    private String emailAluno;

    /** Nome da disciplina */
    private String nomeDisciplina;

    /** Nota da primeira avaliação */
    private Double nota1;

    /** Nota da segunda avaliação */
    private Double nota2;

    /** Média aritmética: (nota1 + nota2) / 2 */
    private Double media;

    /** Status da matrícula: MATRICULADO, APROVADO, REPROVADO, TRANCADO, DESLIGADO */
    private String status;
}
