"use client";

import { useState, useEffect } from "react";
import api from "@/services/api";
import { RelatorioFilter, RelatorioResponse } from "@/types";
import { Download, Search, FileSpreadsheet, FileText } from "lucide-react";

export default function RelatoriosPage() {
  const [resultados, setResultados] = useState<RelatorioResponse[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [isExportingExcel, setIsExportingExcel] = useState(false);
  const [isExportingCsv, setIsExportingCsv] = useState(false);

  // Estado dos filtros
  const [filtros, setFiltros] = useState<RelatorioFilter>({
    nomeAluno: "",
    nomeDisciplina: "",
    status: "",
    notaMinima: undefined,
    notaMaxima: undefined,
  });

  // ─── Pesquisa Interativa ──────────────────────────────────────────
  const handlePesquisar = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    setIsLoading(true);
    try {
      const response = await api.get<RelatorioResponse[]>("/relatorios/matriculas", {
        params: filtros,
      });
      setResultados(response.data);
    } catch (error) {
      console.error("Erro ao pesquisar relatórios:", error);
    } finally {
      setIsLoading(false);
    }
  };

  // Buscar tudo no mount inicial
  useEffect(() => {
    handlePesquisar();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ─── Lógica de Exportação (Forçar Download no Browser) ────────────
  const handleExportar = async (tipo: "excel" | "csv") => {
    const isExcel = tipo === "excel";
    isExcel ? setIsExportingExcel(true) : setIsExportingCsv(true);

    try {
      const response = await api.get(`/relatorios/matriculas/${tipo}`, {
        params: filtros,
        responseType: "blob", // Importante: dizer ao Axios para tratar a resposta como Blob (ficheiro binário)
      });

      // Extrair nome do ficheiro do header Content-Disposition (se existir)
      const disposition = response.headers["content-disposition"];
      let filename = `relatorio_matriculas.${isExcel ? "xlsx" : "csv"}`;
      if (disposition && disposition.indexOf("attachment") !== -1) {
        const filenameRegex = /filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/;
        const matches = filenameRegex.exec(disposition);
        if (matches != null && matches[1]) {
          filename = matches[1].replace(/['"]/g, "");
        }
      }

      // Criar URL para o Blob e forçar clique
      const blob = new Blob([response.data], {
        type: isExcel
          ? "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          : "text/csv;charset=utf-8;",
      });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.setAttribute("download", filename);
      document.body.appendChild(link);
      link.click();
      
      // Limpeza
      link.parentNode?.removeChild(link);
      window.URL.revokeObjectURL(url);
    } catch (error) {
      console.error(`Erro ao exportar ${tipo}:`, error);
      alert(`Ocorreu um erro ao exportar para ${isExcel ? "Excel" : "CSV"}.`);
    } finally {
      isExcel ? setIsExportingExcel(false) : setIsExportingCsv(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header e Ações */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Pesquisa Interativa e Relatórios</h1>
          <p className="text-slate-500 mt-1">Filtre dados académicos e exporte resultados personalizados.</p>
        </div>
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => handleExportar("csv")}
            disabled={isExportingCsv || resultados.length === 0}
            className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 text-slate-700 font-medium rounded-xl hover:bg-slate-50 hover:text-slate-900 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-sm"
          >
            {isExportingCsv ? (
              <div className="w-4 h-4 border-2 border-slate-300 border-t-slate-600 rounded-full animate-spin" />
            ) : (
              <FileText className="w-4 h-4 text-emerald-600" />
            )}
            <span>Exportar CSV</span>
          </button>
          <button
            onClick={() => handleExportar("excel")}
            disabled={isExportingExcel || resultados.length === 0}
            className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white font-medium rounded-xl hover:bg-indigo-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed shadow-sm shadow-indigo-600/20"
          >
            {isExportingExcel ? (
              <div className="w-4 h-4 border-2 border-indigo-200 border-t-white rounded-full animate-spin" />
            ) : (
              <FileSpreadsheet className="w-4 h-4" />
            )}
            <span>Exportar Excel</span>
          </button>
        </div>
      </div>

      {/* Painel de Filtros */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6">
        <form onSubmit={handlePesquisar} className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4 items-end">
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-500 uppercase tracking-wider">Aluno</label>
            <input
              type="text"
              placeholder="Nome do aluno"
              value={filtros.nomeAluno}
              onChange={(e) => setFiltros({ ...filtros, nomeAluno: e.target.value })}
              className="w-full px-4 py-2 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 outline-none text-sm"
            />
          </div>
          
          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-500 uppercase tracking-wider">Disciplina</label>
            <input
              type="text"
              placeholder="Nome da disciplina"
              value={filtros.nomeDisciplina}
              onChange={(e) => setFiltros({ ...filtros, nomeDisciplina: e.target.value })}
              className="w-full px-4 py-2 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 outline-none text-sm"
            />
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-500 uppercase tracking-wider">Status</label>
            <select
              value={filtros.status}
              onChange={(e) => setFiltros({ ...filtros, status: e.target.value })}
              className="w-full px-4 py-2 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 outline-none text-sm"
            >
              <option value="">Todos</option>
              <option value="MATRICULADO">Matriculado</option>
              <option value="APROVADO">Aprovado</option>
              <option value="REPROVADO">Reprovado</option>
              <option value="TRANCADO">Trancado</option>
              <option value="DESLIGADO">Desligado</option>
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-medium text-slate-500 uppercase tracking-wider">Média Mín/Máx</label>
            <div className="flex gap-2">
              <input
                type="number"
                step="0.1"
                min="0"
                max="10"
                placeholder="Mín"
                value={filtros.notaMinima || ""}
                onChange={(e) => setFiltros({ ...filtros, notaMinima: e.target.value ? parseFloat(e.target.value) : undefined })}
                className="w-1/2 px-3 py-2 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 outline-none text-sm"
              />
              <input
                type="number"
                step="0.1"
                min="0"
                max="10"
                placeholder="Máx"
                value={filtros.notaMaxima || ""}
                onChange={(e) => setFiltros({ ...filtros, notaMaxima: e.target.value ? parseFloat(e.target.value) : undefined })}
                className="w-1/2 px-3 py-2 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 outline-none text-sm"
              />
            </div>
          </div>

          <button
            type="submit"
            className="w-full flex items-center justify-center gap-2 px-4 py-2 bg-slate-900 text-white font-medium rounded-xl hover:bg-slate-800 transition-colors shadow-sm"
          >
            <Search className="w-4 h-4" />
            <span>Pesquisar</span>
          </button>
        </form>
      </div>

      {/* Resultados em Tabela */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden">
        {isLoading ? (
          <div className="p-12 flex flex-col items-center justify-center">
            <div className="w-8 h-8 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin mb-4" />
            <p className="text-slate-500">A processar pesquisa...</p>
          </div>
        ) : resultados.length === 0 ? (
          <div className="p-12 text-center">
            <div className="w-16 h-16 bg-slate-50 rounded-full flex items-center justify-center mx-auto mb-4">
              <Search className="w-6 h-6 text-slate-400" />
            </div>
            <h3 className="text-lg font-semibold text-slate-900 mb-1">Nenhum resultado</h3>
            <p className="text-slate-500">Altere os filtros acima para pesquisar novamente.</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-medium">
                <tr>
                  <th className="px-6 py-4">Aluno</th>
                  <th className="px-6 py-4">Disciplina</th>
                  <th className="px-6 py-4 text-center">Nota 1</th>
                  <th className="px-6 py-4 text-center">Nota 2</th>
                  <th className="px-6 py-4 text-center">Média</th>
                  <th className="px-6 py-4 text-right">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {resultados.map((item, idx) => (
                  <tr key={idx} className="hover:bg-slate-50/50 transition-colors">
                    <td className="px-6 py-4">
                      <div className="font-medium text-slate-900">{item.nomeAluno}</div>
                      <div className="text-xs text-slate-500 mt-0.5">{item.emailAluno}</div>
                    </td>
                    <td className="px-6 py-4 text-slate-700">{item.nomeDisciplina}</td>
                    <td className="px-6 py-4 text-center text-slate-700">{item.nota1 !== null ? item.nota1 : "-"}</td>
                    <td className="px-6 py-4 text-center text-slate-700">{item.nota2 !== null ? item.nota2 : "-"}</td>
                    <td className="px-6 py-4 text-center">
                      <span className={`font-medium ${item.media && item.media >= 7 ? 'text-emerald-600' : item.media && item.media < 7 ? 'text-rose-600' : 'text-slate-700'}`}>
                        {item.media !== null ? item.media : "-"}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-right">
                      <span className={`inline-flex px-2.5 py-1 rounded-full text-xs font-medium
                        ${item.status === 'APROVADO' ? 'bg-emerald-100 text-emerald-700' : ''}
                        ${item.status === 'REPROVADO' ? 'bg-rose-100 text-rose-700' : ''}
                        ${item.status === 'MATRICULADO' ? 'bg-blue-100 text-blue-700' : ''}
                        ${item.status === 'TRANCADO' ? 'bg-amber-100 text-amber-700' : ''}
                        ${item.status === 'DESLIGADO' ? 'bg-slate-100 text-slate-700' : ''}
                      `}>
                        {item.status}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <div className="px-6 py-4 bg-slate-50 border-t border-slate-200 text-sm text-slate-500">
              A mostrar <span className="font-medium text-slate-900">{resultados.length}</span> resultados filtrados.
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
