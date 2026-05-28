package br.com.alunoonline.api.specification;

import br.com.alunoonline.api.model.Aluno;
import br.com.alunoonline.api.model.Disciplina;
import br.com.alunoonline.api.model.MatriculaAluno;
import jakarta.persistence.criteria.*;
import org.springframework.data.jpa.domain.Specification;

/**
 * Classe utilitária com métodos estáticos que constroem {@link Specification}
 * para filtragem dinâmica de matrículas.
 *
 * <p>Cada método retorna um {@code Specification<MatriculaAluno>} que pode
 * ser combinado com outros via {@code Specification.where(...).and(...)},
 * permitindo ao utilizador construir queries personalizadas.</p>
 *
 * <p>Utiliza o padrão Criteria API do JPA internamente, abstraindo a
 * complexidade dos JOINs e predicados para o consumidor.</p>
 *
 * <p><strong>Exemplo de uso no serviço:</strong></p>
 * <pre>{@code
 * Specification<MatriculaAluno> spec = Specification
 *     .where(MatriculaAlunoSpecification.porNomeAluno("João"))
 *     .and(MatriculaAlunoSpecification.porStatus("APROVADO"))
 *     .and(MatriculaAlunoSpecification.porNotaMinima(7.0));
 * List<MatriculaAluno> resultados = repository.findAll(spec);
 * }</pre>
 */
public class MatriculaAlunoSpecification {

    private MatriculaAlunoSpecification() {
        // Classe utilitária — impedir instanciação
    }

    /**
     * Filtra por nome do aluno (busca parcial, case-insensitive).
     * Usa LIKE com wildcard em ambos os lados para busca flexível.
     *
     * @param nomeAluno texto parcial a pesquisar no nome do aluno
     * @return Specification que filtra pelo nome do aluno
     */
    public static Specification<MatriculaAluno> porNomeAluno(String nomeAluno) {
        return (root, query, cb) -> {
            if (nomeAluno == null || nomeAluno.isBlank()) {
                return cb.conjunction(); // Sem filtro — retorna true
            }
            // JOIN com a entidade Aluno para acessar o campo nomeCompleto
            Join<MatriculaAluno, Aluno> alunoJoin = root.join("aluno", JoinType.INNER);
            return cb.like(
                    cb.lower(alunoJoin.get("nomeCompleto")),
                    "%" + nomeAluno.toLowerCase() + "%"
            );
        };
    }

    /**
     * Filtra por ID da disciplina (correspondência exacta).
     *
     * @param disciplinaId ID da disciplina
     * @return Specification que filtra pelo ID da disciplina
     */
    public static Specification<MatriculaAluno> porDisciplinaId(Long disciplinaId) {
        return (root, query, cb) -> {
            if (disciplinaId == null) {
                return cb.conjunction();
            }
            Join<MatriculaAluno, Disciplina> disciplinaJoin = root.join("disciplina", JoinType.INNER);
            return cb.equal(disciplinaJoin.get("id"), disciplinaId);
        };
    }

    /**
     * Filtra por nome da disciplina (busca parcial, case-insensitive).
     *
     * @param nomeDisciplina texto parcial a pesquisar no nome da disciplina
     * @return Specification que filtra pelo nome da disciplina
     */
    public static Specification<MatriculaAluno> porNomeDisciplina(String nomeDisciplina) {
        return (root, query, cb) -> {
            if (nomeDisciplina == null || nomeDisciplina.isBlank()) {
                return cb.conjunction();
            }
            Join<MatriculaAluno, Disciplina> disciplinaJoin = root.join("disciplina", JoinType.INNER);
            return cb.like(
                    cb.lower(disciplinaJoin.get("nome")),
                    "%" + nomeDisciplina.toLowerCase() + "%"
            );
        };
    }

    /**
     * Filtra por status da matrícula (correspondência exacta, case-insensitive).
     *
     * @param status valor do status: MATRICULADO, APROVADO, REPROVADO, TRANCADO, DESLIGADO
     * @return Specification que filtra pelo status
     */
    public static Specification<MatriculaAluno> porStatus(String status) {
        return (root, query, cb) -> {
            if (status == null || status.isBlank()) {
                return cb.conjunction();
            }
            return cb.equal(
                    cb.upper(root.get("status").as(String.class)),
                    status.toUpperCase()
            );
        };
    }

    /**
     * Filtra matrículas cuja média ((nota1 + nota2) / 2) é >= ao valor informado.
     * Apenas considera matrículas com ambas as notas preenchidas.
     *
     * @param notaMinima valor mínimo da média
     * @return Specification com filtro de nota mínima
     */
    public static Specification<MatriculaAluno> porNotaMinima(Double notaMinima) {
        return (root, query, cb) -> {
            if (notaMinima == null) {
                return cb.conjunction();
            }
            // Calcula a média no critério: (nota1 + nota2) / 2 >= notaMinima
            // Garante que ambas as notas não são null
            Expression<Double> media = cb.quot(
                    cb.sum(root.get("nota1"), root.get("nota2")),
                    2.0
            ).as(Double.class);

            return cb.and(
                    cb.isNotNull(root.get("nota1")),
                    cb.isNotNull(root.get("nota2")),
                    cb.greaterThanOrEqualTo(media, notaMinima)
            );
        };
    }

    /**
     * Filtra matrículas cuja média ((nota1 + nota2) / 2) é <= ao valor informado.
     * Apenas considera matrículas com ambas as notas preenchidas.
     *
     * @param notaMaxima valor máximo da média
     * @return Specification com filtro de nota máxima
     */
    public static Specification<MatriculaAluno> porNotaMaxima(Double notaMaxima) {
        return (root, query, cb) -> {
            if (notaMaxima == null) {
                return cb.conjunction();
            }
            Expression<Double> media = cb.quot(
                    cb.sum(root.get("nota1"), root.get("nota2")),
                    2.0
            ).as(Double.class);

            return cb.and(
                    cb.isNotNull(root.get("nota1")),
                    cb.isNotNull(root.get("nota2")),
                    cb.lessThanOrEqualTo(media, notaMaxima)
            );
        };
    }
}
