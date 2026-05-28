package br.com.alunoonline.api.service;

import br.com.alunoonline.api.dtos.RelatorioResponseDTO;
import com.opencsv.CSVWriter;
import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * Serviço dedicado à exportação de dados em diferentes formatos de ficheiro.
 *
 * <p>Responsabilidades:</p>
 * <ul>
 *   <li>Gerar ficheiros Excel (.xlsx) usando Apache POI</li>
 *   <li>Gerar ficheiros CSV usando OpenCSV</li>
 * </ul>
 *
 * <p>Separa a lógica de exportação do serviço de relatórios (Single Responsibility).</p>
 */
@Service
public class ExportService {

    // ═══════════════════════════════════════════════════════════════════
    // Cabeçalhos das colunas do relatório
    // ═══════════════════════════════════════════════════════════════════
    private static final String[] HEADERS = {
            "Nome do Aluno", "Email do Aluno", "Disciplina",
            "Nota 1", "Nota 2", "Média", "Status"
    };

    /**
     * Gera um ficheiro Excel (.xlsx) a partir de uma lista de relatórios.
     *
     * <p>Cria um workbook com uma sheet "Relatório de Matrículas", formatada com:</p>
     * <ul>
     *   <li>Header row com estilo bold e fundo cinza</li>
     *   <li>Colunas auto-dimensionadas</li>
     *   <li>Notas formatadas com 2 casas decimais</li>
     * </ul>
     *
     * @param dados lista de DTOs do relatório
     * @return array de bytes representando o ficheiro .xlsx
     * @throws IOException se houver erro na escrita do ficheiro
     */
    public byte[] gerarExcel(List<RelatorioResponseDTO> dados) throws IOException {
        try (XSSFWorkbook workbook = new XSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {

            Sheet sheet = workbook.createSheet("Relatório de Matrículas");

            // ─── Estilo do cabeçalho ──────────────────────────────────
            CellStyle headerStyle = workbook.createCellStyle();
            Font headerFont = workbook.createFont();
            headerFont.setBold(true);
            headerStyle.setFont(headerFont);
            headerStyle.setFillForegroundColor(IndexedColors.GREY_25_PERCENT.getIndex());
            headerStyle.setFillPattern(FillPatternType.SOLID_FOREGROUND);
            headerStyle.setBorderBottom(BorderStyle.THIN);

            // ─── Estilo para números com 2 casas decimais ─────────────
            CellStyle numberStyle = workbook.createCellStyle();
            DataFormat format = workbook.createDataFormat();
            numberStyle.setDataFormat(format.getFormat("0.00"));

            // ─── Criar header row ─────────────────────────────────────
            Row headerRow = sheet.createRow(0);
            for (int i = 0; i < HEADERS.length; i++) {
                Cell cell = headerRow.createCell(i);
                cell.setCellValue(HEADERS[i]);
                cell.setCellStyle(headerStyle);
            }

            // ─── Preencher dados ──────────────────────────────────────
            for (int rowIdx = 0; rowIdx < dados.size(); rowIdx++) {
                RelatorioResponseDTO dto = dados.get(rowIdx);
                Row row = sheet.createRow(rowIdx + 1);

                // Coluna 0: Nome do Aluno
                row.createCell(0).setCellValue(
                        dto.getNomeAluno() != null ? dto.getNomeAluno() : "");

                // Coluna 1: Email do Aluno
                row.createCell(1).setCellValue(
                        dto.getEmailAluno() != null ? dto.getEmailAluno() : "");

                // Coluna 2: Disciplina
                row.createCell(2).setCellValue(
                        dto.getNomeDisciplina() != null ? dto.getNomeDisciplina() : "");

                // Coluna 3: Nota 1
                Cell cellNota1 = row.createCell(3);
                if (dto.getNota1() != null) {
                    cellNota1.setCellValue(dto.getNota1());
                    cellNota1.setCellStyle(numberStyle);
                }

                // Coluna 4: Nota 2
                Cell cellNota2 = row.createCell(4);
                if (dto.getNota2() != null) {
                    cellNota2.setCellValue(dto.getNota2());
                    cellNota2.setCellStyle(numberStyle);
                }

                // Coluna 5: Média
                Cell cellMedia = row.createCell(5);
                if (dto.getMedia() != null) {
                    cellMedia.setCellValue(dto.getMedia());
                    cellMedia.setCellStyle(numberStyle);
                }

                // Coluna 6: Status
                row.createCell(6).setCellValue(
                        dto.getStatus() != null ? dto.getStatus() : "");
            }

            // ─── Auto-dimensionar colunas ─────────────────────────────
            for (int i = 0; i < HEADERS.length; i++) {
                sheet.autoSizeColumn(i);
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    /**
     * Gera um ficheiro CSV a partir de uma lista de relatórios.
     *
     * <p>Usa codificação UTF-8 com BOM para compatibilidade com Excel.
     * Valores null são escritos como string vazia.</p>
     *
     * @param dados lista de DTOs do relatório
     * @return array de bytes representando o ficheiro .csv (UTF-8 com BOM)
     * @throws IOException se houver erro na escrita do ficheiro
     */
    public byte[] gerarCsv(List<RelatorioResponseDTO> dados) throws IOException {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            // Escrever BOM UTF-8 para compatibilidade com Excel
            out.write(0xEF);
            out.write(0xBB);
            out.write(0xBF);

            try (CSVWriter writer = new CSVWriter(
                    new OutputStreamWriter(out, StandardCharsets.UTF_8))) {

                // ─── Escrever cabeçalho ───────────────────────────────
                writer.writeNext(HEADERS);

                // ─── Escrever dados ───────────────────────────────────
                for (RelatorioResponseDTO dto : dados) {
                    String[] row = {
                            dto.getNomeAluno() != null ? dto.getNomeAluno() : "",
                            dto.getEmailAluno() != null ? dto.getEmailAluno() : "",
                            dto.getNomeDisciplina() != null ? dto.getNomeDisciplina() : "",
                            dto.getNota1() != null ? String.format("%.2f", dto.getNota1()) : "",
                            dto.getNota2() != null ? String.format("%.2f", dto.getNota2()) : "",
                            dto.getMedia() != null ? String.format("%.2f", dto.getMedia()) : "",
                            dto.getStatus() != null ? dto.getStatus() : ""
                    };
                    writer.writeNext(row);
                }
            }

            return out.toByteArray();
        }
    }
}
