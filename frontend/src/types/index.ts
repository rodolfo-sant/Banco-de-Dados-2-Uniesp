// ============================================================================
// TIPOS TYPESCRIPT — Aluno Online Frontend
// ============================================================================
// Espelham as entidades e DTOs do backend Spring Boot
// ============================================================================

// ═══════════════════════════════════════════════════════════════════════════
// ENTIDADES PRINCIPAIS (CRUD)
// ═══════════════════════════════════════════════════════════════════════════

export interface Aluno {
  id?: number;
  nomeCompleto: string;
  cpf: string;
  email: string;
}

export interface Professor {
  id?: number;
  nome: string;
  email: string;
  cpf: string;
}

export interface Disciplina {
  id?: number;
  nome: string;
  cargaHoraria: number;
  professor?: Professor;
}

export interface MatriculaAluno {
  id?: number;
  aluno: Aluno;
  disciplina: Disciplina;
  nota1: number | null;
  nota2: number | null;
  status: MatriculaStatus;
}

export type MatriculaStatus =
  | "MATRICULADO"
  | "APROVADO"
  | "REPROVADO"
  | "TRANCADO"
  | "DESLIGADO";

// ═══════════════════════════════════════════════════════════════════════════
// DTOs DE RELATÓRIO (Módulo 2)
// ═══════════════════════════════════════════════════════════════════════════

export interface RelatorioFilter {
  nomeAluno?: string;
  disciplinaId?: number;
  nomeDisciplina?: string;
  status?: string;
  notaMinima?: number;
  notaMaxima?: number;
}

export interface RelatorioResponse {
  nomeAluno: string;
  emailAluno: string;
  nomeDisciplina: string;
  nota1: number | null;
  nota2: number | null;
  media: number | null;
  status: string;
}

// ═══════════════════════════════════════════════════════════════════════════
// DTOs DE ANALYTICS (Módulo 3)
// ═══════════════════════════════════════════════════════════════════════════

export interface AlunoRisco {
  alunoId: number;
  alunoNome: string;
  alunoEmail: string;
  mediaGlobal: number | null;
  qtdReprovacoes: number;
  qtdTrancamentos: number;
  qtdEmCurso: number;
  scoreRisco: number | null;
  classificacaoRisco: string;
  totalMatriculas: number;
}

export interface PanoramaDisciplina {
  disciplinaId: number;
  disciplinaNome: string;
  cargaHoraria: number | null;
  professorNome: string | null;
  totalMatriculas: number;
  qtdAprovados: number;
  qtdReprovados: number;
  qtdTrancados: number;
  mediaTurma: number | null;
  desvioPadrao: number | null;
  taxaAprovacaoPct: number | null;
  taxaReprovacaoPct: number | null;
}

export interface HistoricoAcademico {
  alunoId: number;
  alunoNome: string;
  alunoEmail: string;
  totalDisciplinas: number;
  qtdAprovadas: number;
  qtdReprovadas: number;
  qtdTrancadas: number;
  qtdEmCurso: number;
  qtdDesligadas: number;
  mediaGlobal: number | null;
  pctAprovacao: number | null;
  pctReprovacao: number | null;
  pctTrancamento: number | null;
}

// ═══════════════════════════════════════════════════════════════════════════
// TIPOS UTILITÁRIOS
// ═══════════════════════════════════════════════════════════════════════════

export interface ApiMessage {
  mensagem: string;
  status: string;
  semestre?: string;
}
