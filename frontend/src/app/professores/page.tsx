"use client";

import { useState, useEffect } from "react";
import api from "@/services/api";
import { Professor } from "@/types";
import DataTable from "@/components/DataTable";
import FormModal from "@/components/FormModal";
import { Plus } from "lucide-react";

export default function ProfessoresPage() {
  const [professores, setProfessores] = useState<Professor[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingProfessor, setEditingProfessor] = useState<Professor | null>(null);
  
  const [formData, setFormData] = useState({
    nome: "",
    cpf: "",
    email: "",
  });

  const fetchProfessores = async () => {
    setIsLoading(true);
    try {
      const response = await api.get<Professor[]>("/professores");
      setProfessores(response.data);
    } catch (error) {
      console.error("Erro ao carregar professores:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchProfessores();
  }, []);

  const handleOpenModal = (professor?: Professor) => {
    if (professor) {
      setEditingProfessor(professor);
      setFormData({
        nome: professor.nome,
        cpf: professor.cpf,
        email: professor.email,
      });
    } else {
      setEditingProfessor(null);
      setFormData({ nome: "", cpf: "", email: "" });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingProfessor(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      if (editingProfessor?.id) {
        await api.put(`/professores/${editingProfessor.id}`, formData);
      } else {
        await api.post("/professores", formData);
      }
      fetchProfessores();
      handleCloseModal();
    } catch (error) {
      console.error("Erro ao salvar professor:", error);
      alert("Ocorreu um erro ao salvar o professor.");
    }
  };

  const handleDelete = async (professor: Professor) => {
    if (!professor.id) return;
    if (confirm(`Tem a certeza que deseja excluir o professor ${professor.nome}?`)) {
      try {
        await api.delete(`/professores/${professor.id}`);
        fetchProfessores();
      } catch (error) {
        console.error("Erro ao excluir professor:", error);
        alert("Não foi possível excluir. O professor pode estar associado a disciplinas.");
      }
    }
  };

  const columns = [
    { key: "id" as keyof Professor, label: "ID" },
    { key: "nome" as keyof Professor, label: "Nome" },
    { key: "cpf" as keyof Professor, label: "CPF" },
    { key: "email" as keyof Professor, label: "E-mail" },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Gestão de Professores</h1>
          <p className="text-slate-500 mt-1">Gerencie o corpo docente da instituição.</p>
        </div>
        <button
          onClick={() => handleOpenModal()}
          className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white font-medium rounded-xl hover:bg-indigo-700 transition-all focus:ring-2 focus:ring-offset-2 focus:ring-indigo-600"
        >
          <Plus className="w-4 h-4" />
          <span>Novo Professor</span>
        </button>
      </div>

      <DataTable
        data={professores}
        columns={columns}
        isLoading={isLoading}
        onEdit={handleOpenModal}
        onDelete={handleDelete}
      />

      <FormModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        title={editingProfessor ? "Editar Professor" : "Novo Professor"}
      >
        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-1">
            <label htmlFor="nome" className="block text-sm font-medium text-slate-700">Nome</label>
            <input
              type="text"
              id="nome"
              required
              value={formData.nome}
              onChange={(e) => setFormData({ ...formData, nome: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
            />
          </div>
          <div className="space-y-1">
            <label htmlFor="cpf" className="block text-sm font-medium text-slate-700">CPF</label>
            <input
              type="text"
              id="cpf"
              required
              value={formData.cpf}
              onChange={(e) => setFormData({ ...formData, cpf: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
            />
          </div>
          <div className="space-y-1">
            <label htmlFor="email" className="block text-sm font-medium text-slate-700">E-mail</label>
            <input
              type="email"
              id="email"
              required
              value={formData.email}
              onChange={(e) => setFormData({ ...formData, email: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
            />
          </div>
          <div className="pt-4 flex gap-3">
            <button type="button" onClick={handleCloseModal} className="flex-1 px-4 py-2.5 text-slate-700 bg-slate-100 hover:bg-slate-200 font-medium rounded-xl transition-colors">
              Cancelar
            </button>
            <button type="submit" className="flex-1 px-4 py-2.5 text-white bg-indigo-600 hover:bg-indigo-700 font-medium rounded-xl shadow-sm hover:shadow-md transition-all">
              {editingProfessor ? "Guardar" : "Criar"}
            </button>
          </div>
        </form>
      </FormModal>
    </div>
  );
}
