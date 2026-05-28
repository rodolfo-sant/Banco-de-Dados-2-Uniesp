"use client";

import { useEffect, useState } from "react";
import MetricCard from "@/components/MetricCard";
import BarChartCard from "@/components/BarChartCard";
import api from "@/services/api";
import { PanoramaDisciplina, AlunoRisco } from "@/types";
import { Users, AlertTriangle, UserMinus, GraduationCap } from "lucide-react";

export default function DashboardPage() {
  const [panorama, setPanorama] = useState<PanoramaDisciplina[]>([]);
  const [riscoCritico, setRiscoCritico] = useState<AlunoRisco[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchAnalytics = async () => {
      setIsLoading(true);
      try {
        // Buscar panorama de disciplinas para o gráfico
        const resPanorama = await api.get<PanoramaDisciplina[]>("/analytics/panorama-disciplinas");
        setPanorama(resPanorama.data);

        // Buscar alunos em risco crítico para a métrica
        const resRisco = await api.get<AlunoRisco[]>("/analytics/alunos-risco?classificacao=CRITICO");
        setRiscoCritico(resRisco.data);
      } catch (error) {
        console.error("Erro ao carregar dados analíticos:", error);
      } finally {
        setIsLoading(false);
      }
    };

    fetchAnalytics();
  }, []);

  // Calcular métricas agregadas a partir do panorama
  const totalAlunos = panorama.reduce((acc, curr) => acc + curr.totalMatriculas, 0);
  const totalReprovados = panorama.reduce((acc, curr) => acc + curr.qtdReprovados, 0);
  const taxaReprovacaoGeral = totalAlunos > 0 ? (totalReprovados / totalAlunos) * 100 : 0;

  // Dados para o gráfico de médias
  const chartData = panorama.map((p) => ({
    disciplina: p.disciplinaNome.substring(0, 15) + (p.disciplinaNome.length > 15 ? "..." : ""),
    media: p.mediaTurma || 0,
  }));

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="w-8 h-8 border-4 border-indigo-200 border-t-indigo-600 rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Dashboard Analítico</h1>
        <p className="text-slate-500 mt-1">Visão geral do desempenho académico da instituição.</p>
      </div>

      {/* Cards de Métricas */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <MetricCard
          title="Total de Matrículas Ativas"
          value={totalAlunos}
          icon={Users}
          colorVariant="indigo"
          trend={{ value: "+5.2%", isPositive: true }}
        />
        <MetricCard
          title="Alunos em Risco Crítico"
          value={riscoCritico.length}
          icon={AlertTriangle}
          colorVariant="rose"
          trend={{ value: "-2.1%", isPositive: true }}
        />
        <MetricCard
          title="Taxa de Reprovação Global"
          value={`${taxaReprovacaoGeral.toFixed(1)}%`}
          icon={UserMinus}
          colorVariant="amber"
        />
        <MetricCard
          title="Média Geral do Sistema"
          value={(panorama.reduce((acc, curr) => acc + (curr.mediaTurma || 0), 0) / (panorama.length || 1)).toFixed(2)}
          icon={GraduationCap}
          colorVariant="emerald"
        />
      </div>

      {/* Área de Gráficos */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Gráfico principal ocupa 2/3 */}
        <div className="lg:col-span-2">
          <BarChartCard
            title="Média de Notas por Disciplina"
            data={chartData}
            xAxisKey="disciplina"
            dataKey="media"
            color="#6366f1"
          />
        </div>

        {/* Painel lateral: Lista de alunos em risco */}
        <div className="bg-white rounded-2xl shadow-sm border border-slate-200 overflow-hidden flex flex-col">
          <div className="p-6 border-b border-slate-100">
            <h3 className="text-base font-semibold text-slate-900">Atenção Prioritária (Crítico)</h3>
          </div>
          <div className="flex-1 overflow-y-auto p-2">
            {riscoCritico.length === 0 ? (
              <div className="p-4 text-center text-slate-500 text-sm">
                Nenhum aluno em risco crítico no momento.
              </div>
            ) : (
              <div className="space-y-1">
                {riscoCritico.slice(0, 6).map((aluno) => (
                  <div key={aluno.alunoId} className="p-4 hover:bg-slate-50 rounded-xl transition-colors">
                    <div className="flex justify-between items-start mb-1">
                      <span className="font-medium text-slate-900 text-sm">{aluno.alunoNome}</span>
                      <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-rose-100 text-rose-700">
                        Score: {aluno.scoreRisco}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500">
                      Média: {aluno.mediaGlobal} • Reprovações: {aluno.qtdReprovacoes}
                    </p>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
