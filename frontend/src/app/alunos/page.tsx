"use client";

import { useState, useEffect } from "react";
import api from "@/services/api";
import { Aluno } from "@/types";
import DataTable from "@/components/DataTable";
import FormModal from "@/components/FormModal";
import { Plus } from "lucide-react";

export default function AlunosPage() {
  const [alunos, setAlunos] = useState<Aluno[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  // Controlo do Modal e Formulário
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingAluno, setEditingAluno] = useState<Aluno | null>(null);
  
  // Estado do Formulário
  const [formData, setFormData] = useState({
    nomeCompleto: "",
    cpf: "",
    email: "",
  });

  // ─── Carregar Alunos ──────────────────────────────────────────────
  const fetchAlunos = async () => {
    setIsLoading(true);
    try {
      const response = await api.get<Aluno[]>("/alunos");
      setAlunos(response.data);
    } catch (error) {
      console.error("Erro ao carregar alunos:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAlunos();
  }, []);

  // ─── Handlers do Formulário ───────────────────────────────────────
  const handleOpenModal = (aluno?: Aluno) => {
    if (aluno) {
      setEditingAluno(aluno);
      setFormData({
        nomeCompleto: aluno.nomeCompleto,
        cpf: aluno.cpf,
        email: aluno.email,
      });
    } else {
      setEditingAluno(null);
      setFormData({ nomeCompleto: "", cpf: "", email: "" });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingAluno(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingAluno?.id) {
        // PUT: Atualizar
        await api.put(`/alunos/${editingAluno.id}`, formData);
      } else {
        // POST: Criar
        await api.post("/alunos", formData);
      }
      fetchAlunos(); // Recarregar lista
      handleCloseModal();
    } catch (error) {
      console.error("Erro ao salvar aluno:", error);
      alert("Ocorreu um erro ao salvar o aluno. Verifique os logs.");
    }
  };

  const handleDelete = async (aluno: Aluno) => {
    if (!aluno.id) return;
    if (confirm(`Tem a certeza que deseja excluir o aluno ${aluno.nomeCompleto}?`)) {
      try {
        await api.delete(`/alunos/${aluno.id}`);
        fetchAlunos();
      } catch (error) {
        console.error("Erro ao excluir aluno:", error);
        alert("Não foi possível excluir o aluno. Ele pode ter matrículas ativas.");
      }
    }
  };

  // ─── Configuração da Tabela ───────────────────────────────────────
  const columns = [
    { key: "id" as keyof Aluno, label: "ID" },
    { key: "nomeCompleto" as keyof Aluno, label: "Nome Completo" },
    { key: "cpf" as keyof Aluno, label: "CPF" },
    { key: "email" as keyof Aluno, label: "E-mail" },
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Gestão de Alunos</h1>
          <p className="text-slate-500 mt-1">Gerencie os alunos registados na instituição.</p>
        </div>
        <button
          onClick={() => handleOpenModal()}
          className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white font-medium rounded-xl hover:bg-indigo-700 hover:shadow-md hover:shadow-indigo-600/20 transition-all focus:ring-2 focus:ring-offset-2 focus:ring-indigo-600"
        >
          <Plus className="w-4 h-4" />
          <span>Novo Aluno</span>
        </button>
      </div>

      {/* Tabela */}
      <DataTable
        data={alunos}
        columns={columns}
        isLoading={isLoading}
        onEdit={handleOpenModal}
        onDelete={handleDelete}
      />

      {/* Modal de Formulário */}
      <FormModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        title={editingAluno ? "Editar Aluno" : "Novo Aluno"}
      >
        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-1">
            <label htmlFor="nomeCompleto" className="block text-sm font-medium text-slate-700">
              Nome Completo
            </label>
            <input
              type="text"
              id="nomeCompleto"
              required
              value={formData.nomeCompleto}
              onChange={(e) => setFormData({ ...formData, nomeCompleto: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
              placeholder="Ex: João Silva"
            />
          </div>

          <div className="space-y-1">
            <label htmlFor="cpf" className="block text-sm font-medium text-slate-700">
              CPF
            </label>
            <input
              type="text"
              id="cpf"
              required
              value={formData.cpf}
              onChange={(e) => setFormData({ ...formData, cpf: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
              placeholder="000.000.000-00"
            />
          </div>

          <div className="space-y-1">
            <label htmlFor="email" className="block text-sm font-medium text-slate-700">
              E-mail
            </label>
            <input
              type="email"
              id="email"
              required
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
              placeholder="joao.silva@escola.pt"
            />
          </div>

          <div className="pt-4 flex gap-3">
            <button
              type="button"
              onClick={handleCloseModal}
              className="flex-1 px-4 py-2.5 text-slate-700 bg-slate-100 hover:bg-slate-200 font-medium rounded-xl transition-colors"
            >
              Cancelar
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2.5 text-white bg-indigo-600 hover:bg-indigo-700 font-medium rounded-xl shadow-sm hover:shadow-md transition-all"
            >
              {editingAluno ? "Guardar Alterações" : "Criar Aluno"}
            </button>
          </div>
        </form>
      </FormModal>
    </div>
  );
}
