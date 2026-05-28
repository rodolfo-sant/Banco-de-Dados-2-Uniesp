package br.com.alunoonline.api.dtos;

import lombok.Data;

/**
 * DTO para receber os parâmetros de filtragem dinâmica do módulo de relatórios.
 *
 * <p>Cada campo é opcional — apenas os campos preenchidos serão usados como
 * critério de filtro. Isto permite ao utilizador construir queries personalizadas
 * combinando diferentes filtros conforme necessidade.</p>
 *
 * <p>Exemplo de uso via query params:
 * {@code GET /relatorios/matriculas?nomeAluno=João&status=APROVADO&notaMinima=7.0}</p>
 */
@Data
public class RelatorioFilterDTO {

    /** Filtro por nome do aluno (busca parcial, case-insensitive) */
    private String nomeAluno;

    /** Filtro por ID da disciplina (correspondência exacta) */
    private Long disciplinaId;

    /** Filtro por nome da disciplina (busca parcial, case-insensitive) */
    private String nomeDisciplina;

    /** Filtro por status da matrícula: MATRICULADO, APROVADO, REPROVADO, TRANCADO, DESLIGADO */
    private String status;

    /** Filtro por nota mínima (média >= notaMinima) */
    private Double notaMinima;

    /** Filtro por nota máxima (média <= notaMaxima) */
    private Double notaMaxima;
}
