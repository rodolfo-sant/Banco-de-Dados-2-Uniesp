package br.com.alunoonline.api.service;

import br.com.alunoonline.api.dtos.RelatorioFilterDTO;
import br.com.alunoonline.api.dtos.RelatorioResponseDTO;
import br.com.alunoonline.api.model.MatriculaAluno;
import br.com.alunoonline.api.repository.MatriculaAlunoRepository;
import br.com.alunoonline.api.specification.MatriculaAlunoSpecification;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

/**
 * Serviço de relatórios dinâmicos para matrículas.
 *
 * <p>Orquestra o fluxo de pesquisa interactiva:</p>
 * <ol>
 *   <li>Recebe os filtros do utilizador via {@link RelatorioFilterDTO}</li>
 *   <li>Constrói uma {@link Specification} composta a partir dos filtros preenchidos</li>
 *   <li>Executa a query dinâmica via {@link MatriculaAlunoRepository}</li>
 *   <li>Transforma os resultados em {@link RelatorioResponseDTO}</li>
 * </ol>
 *
 * <p>A separação entre filtro → specification → query → DTO garante que
 * novos filtros podem ser adicionados sem alterar a lógica existente.</p>
 */
@Service
public class RelatorioService {

    @Autowired
    private MatriculaAlunoRepository matriculaAlunoRepository;

    /**
     * Pesquisa matrículas aplicando filtros dinâmicos e devolve DTOs formatados.
     *
     * <p>Todos os filtros são opcionais. Apenas os campos preenchidos no DTO
     * de filtro serão incluídos na query. Se nenhum filtro for informado,
     * retorna todas as matrículas.</p>
     *
     * @param filtro DTO com os parâmetros de filtragem (todos opcionais)
     * @return lista de DTOs com os dados do relatório
     */
    public List<RelatorioResponseDTO> pesquisarMatriculas(RelatorioFilterDTO filtro) {

        // ─── Construir Specification composta ──────────────────────
        // Cada método da MatriculaAlunoSpecification retorna conjunction()
        // quando o parâmetro é null, efectivamente ignorando o filtro
        Specification<MatriculaAluno> spec = Specification
                .where(MatriculaAlunoSpecification.porNomeAluno(filtro.getNomeAluno()))
                .and(MatriculaAlunoSpecification.porDisciplinaId(filtro.getDisciplinaId()))
                .and(MatriculaAlunoSpecification.porNomeDisciplina(filtro.getNomeDisciplina()))
                .and(MatriculaAlunoSpecification.porStatus(filtro.getStatus()))
                .and(MatriculaAlunoSpecification.porNotaMinima(filtro.getNotaMinima()))
                .and(MatriculaAlunoSpecification.porNotaMaxima(filtro.getNotaMaxima()));

        // ─── Executar query dinâmica ──────────────────────────────
        List<MatriculaAluno> resultados = matriculaAlunoRepository.findAll(spec);

        // ─── Transformar entidades em DTOs ────────────────────────
        return resultados.stream()
                .map(this::converterParaDTO)
                .collect(Collectors.toList());
    }

    /**
     * Converte uma entidade {@link MatriculaAluno} num {@link RelatorioResponseDTO}.
     *
     * <p>Calcula a média aritmética das notas quando ambas estão disponíveis.
     * Resolve os relacionamentos (aluno e disciplina) para extrair nomes.</p>
     *
     * @param matricula entidade de matrícula com relacionamentos carregados
     * @return DTO com dados formatados para o relatório
     */
    private RelatorioResponseDTO converterParaDTO(MatriculaAluno matricula) {
        RelatorioResponseDTO dto = new RelatorioResponseDTO();

        // Dados do aluno (via relacionamento ManyToOne)
        if (matricula.getAluno() != null) {
            dto.setNomeAluno(matricula.getAluno().getNomeCompleto());
            dto.setEmailAluno(matricula.getAluno().getEmail());
        }

        // Dados da disciplina (via relacionamento ManyToOne)
        if (matricula.getDisciplina() != null) {
            dto.setNomeDisciplina(matricula.getDisciplina().getNome());
        }

        // Notas
        dto.setNota1(matricula.getNota1());
        dto.setNota2(matricula.getNota2());

        // Calcular média (apenas se ambas as notas existirem)
        if (matricula.getNota1() != null && matricula.getNota2() != null) {
            double media = (matricula.getNota1() + matricula.getNota2()) / 2.0;
            dto.setMedia(Math.round(media * 100.0) / 100.0); // Arredondar para 2 casas
        }

        // Status (converter enum para string)
        if (matricula.getStatus() != null) {
            dto.setStatus(matricula.getStatus().name());
        }

        return dto;
    }
}
