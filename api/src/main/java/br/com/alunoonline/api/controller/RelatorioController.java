package br.com.alunoonline.api.controller;

import br.com.alunoonline.api.dtos.RelatorioFilterDTO;
import br.com.alunoonline.api.dtos.RelatorioResponseDTO;
import br.com.alunoonline.api.service.ExportService;
import br.com.alunoonline.api.service.RelatorioService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Controller REST para o módulo de Relatórios Dinâmicos.
 *
 * <p>Disponibiliza endpoints para:</p>
 * <ul>
 *   <li>Pesquisa interactiva com filtros dinâmicos</li>
 *   <li>Exportação do resultado em Excel (.xlsx)</li>
 *   <li>Exportação do resultado em CSV (.csv)</li>
 * </ul>
 *
 * <p>Todos os endpoints aceitam os mesmos query parameters de filtro,
 * garantindo que o resultado exportado corresponde exactamente ao que
 * o utilizador visualizou na pesquisa.</p>
 */
@RestController
@RequestMapping("/relatorios")
public class RelatorioController {

    @Autowired
    private RelatorioService relatorioService;

    @Autowired
    private ExportService exportService;

    /**
     * Pesquisa interactiva de matrículas com filtros dinâmicos.
     *
     * <p>Exemplo de chamada:</p>
     * <pre>
     * GET /relatorios/matriculas?nomeAluno=João&status=APROVADO&notaMinima=7.0
     * </pre>
     *
     * @param nomeAluno     filtro parcial pelo nome do aluno (opcional)
     * @param disciplinaId  filtro pelo ID da disciplina (opcional)
     * @param nomeDisciplina filtro parcial pelo nome da disciplina (opcional)
     * @param status        filtro pelo status da matrícula (opcional)
     * @param notaMinima    filtro pela nota mínima da média (opcional)
     * @param notaMaxima    filtro pela nota máxima da média (opcional)
     * @return lista de matrículas filtradas em formato JSON
     */
    @GetMapping("/matriculas")
    @ResponseStatus(HttpStatus.OK)
    public List<RelatorioResponseDTO> pesquisarMatriculas(
            @RequestParam(required = false) String nomeAluno,
            @RequestParam(required = false) Long disciplinaId,
            @RequestParam(required = false) String nomeDisciplina,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Double notaMinima,
            @RequestParam(required = false) Double notaMaxima) {

        RelatorioFilterDTO filtro = construirFiltro(
                nomeAluno, disciplinaId, nomeDisciplina, status, notaMinima, notaMaxima);

        return relatorioService.pesquisarMatriculas(filtro);
    }

    /**
     * Exporta o resultado da pesquisa filtrada como ficheiro Excel (.xlsx).
     *
     * <p>Devolve o ficheiro via ResponseEntity com headers de download.
     * O nome do ficheiro inclui timestamp para evitar conflitos.</p>
     *
     * @return ResponseEntity com o ficheiro .xlsx para download
     */
    @GetMapping("/matriculas/excel")
    public ResponseEntity<byte[]> exportarExcel(
            @RequestParam(required = false) String nomeAluno,
            @RequestParam(required = false) Long disciplinaId,
            @RequestParam(required = false) String nomeDisciplina,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Double notaMinima,
            @RequestParam(required = false) Double notaMaxima) throws IOException {

        // 1. Aplicar mesmos filtros da pesquisa
        RelatorioFilterDTO filtro = construirFiltro(
                nomeAluno, disciplinaId, nomeDisciplina, status, notaMinima, notaMaxima);
        List<RelatorioResponseDTO> dados = relatorioService.pesquisarMatriculas(filtro);

        // 2. Gerar ficheiro Excel
        byte[] excelBytes = exportService.gerarExcel(dados);

        // 3. Construir resposta com headers de download
        String filename = "relatorio_matriculas_" + gerarTimestamp() + ".xlsx";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType(
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"));
        headers.setContentDispositionFormData("attachment", filename);
        headers.setContentLength(excelBytes.length);

        return new ResponseEntity<>(excelBytes, headers, HttpStatus.OK);
    }

    /**
     * Exporta o resultado da pesquisa filtrada como ficheiro CSV.
     *
     * <p>O CSV é gerado com codificação UTF-8 (com BOM) para
     * compatibilidade com o Microsoft Excel.</p>
     *
     * @return ResponseEntity com o ficheiro .csv para download
     */
    @GetMapping("/matriculas/csv")
    public ResponseEntity<byte[]> exportarCsv(
            @RequestParam(required = false) String nomeAluno,
            @RequestParam(required = false) Long disciplinaId,
            @RequestParam(required = false) String nomeDisciplina,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Double notaMinima,
            @RequestParam(required = false) Double notaMaxima) throws IOException {

        // 1. Aplicar mesmos filtros
        RelatorioFilterDTO filtro = construirFiltro(
                nomeAluno, disciplinaId, nomeDisciplina, status, notaMinima, notaMaxima);
        List<RelatorioResponseDTO> dados = relatorioService.pesquisarMatriculas(filtro);

        // 2. Gerar ficheiro CSV
        byte[] csvBytes = exportService.gerarCsv(dados);

        // 3. Construir resposta
        String filename = "relatorio_matriculas_" + gerarTimestamp() + ".csv";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.parseMediaType("text/csv; charset=UTF-8"));
        headers.setContentDispositionFormData("attachment", filename);
        headers.setContentLength(csvBytes.length);

        return new ResponseEntity<>(csvBytes, headers, HttpStatus.OK);
    }

    // ═══════════════════════════════════════════════════════════════════
    // Métodos auxiliares privados
    // ═══════════════════════════════════════════════════════════════════

    /**
     * Constrói o DTO de filtro a partir dos query parameters individuais.
     * Centraliza a construção para evitar duplicação entre os endpoints.
     */
    private RelatorioFilterDTO construirFiltro(
            String nomeAluno, Long disciplinaId, String nomeDisciplina,
            String status, Double notaMinima, Double notaMaxima) {

        RelatorioFilterDTO filtro = new RelatorioFilterDTO();
        filtro.setNomeAluno(nomeAluno);
        filtro.setDisciplinaId(disciplinaId);
        filtro.setNomeDisciplina(nomeDisciplina);
        filtro.setStatus(status);
        filtro.setNotaMinima(notaMinima);
        filtro.setNotaMaxima(notaMaxima);
        return filtro;
    }

    /**
     * Gera um timestamp formatado para nomes de ficheiros.
     * Formato: yyyyMMdd_HHmmss (ex: 20260528_143015)
     */
    private String gerarTimestamp() {
        return LocalDateTime.now().format(
                DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss"));
    }
}
