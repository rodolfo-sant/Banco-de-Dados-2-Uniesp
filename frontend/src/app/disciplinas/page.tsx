"use client";

import { useState, useEffect } from "react";
import api from "@/services/api";
import { Disciplina, Professor } from "@/types";
import DataTable from "@/components/DataTable";
import FormModal from "@/components/FormModal";
import { Plus } from "lucide-react";

export default function DisciplinasPage() {
  const [disciplinas, setDisciplinas] = useState<Disciplina[]>([]);
  const [professores, setProfessores] = useState<Professor[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingDisciplina, setEditingDisciplina] = useState<Disciplina | null>(null);
  
  const [formData, setFormData] = useState({
    nome: "",
    cargaHoraria: "",
    professor: { id: "" }
  });

  const fetchData = async () => {
    setIsLoading(true);
    try {
      const [resDisciplinas, resProfessores] = await Promise.all([
        api.get<Disciplina[]>("/disciplinas"),
        api.get<Professor[]>("/professores")
      ]);
      setDisciplinas(resDisciplinas.data);
      setProfessores(resProfessores.data);
    } catch (error) {
      console.error("Erro ao carregar dados:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchData();
  }, []);

  const handleOpenModal = (disciplina?: Disciplina) => {
    if (disciplina) {
      setEditingDisciplina(disciplina);
      setFormData({
        nome: disciplina.nome,
        cargaHoraria: disciplina.cargaHoraria.toString(),
        professor: { id: disciplina.professor?.id?.toString() || "" }
      });
    } else {
      setEditingDisciplina(null);
      setFormData({ nome: "", cargaHoraria: "", professor: { id: "" } });
    }
    setIsModalOpen(true);
  };

  const handleCloseModal = () => {
    setIsModalOpen(false);
    setEditingDisciplina(null);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const payload = {
        nome: formData.nome,
        cargaHoraria: parseInt(formData.cargaHoraria),
        professor: formData.professor.id ? { id: parseInt(formData.professor.id) } : null
      };

      if (editingDisciplina?.id) {
        await api.put(`/disciplinas/${editingDisciplina.id}`, payload);
      } else {
        await api.post("/disciplinas", payload);
      }
      fetchData();
      handleCloseModal();
    } catch (error) {
      console.error("Erro ao salvar disciplina:", error);
      alert("Ocorreu um erro ao salvar a disciplina.");
    }
  };

  const handleDelete = async (disciplina: Disciplina) => {
    if (!disciplina.id) return;
    if (confirm(`Tem a certeza que deseja excluir a disciplina ${disciplina.nome}?`)) {
      try {
        await api.delete(`/disciplinas/${disciplina.id}`);
        fetchData();
      } catch (error) {
        console.error("Erro ao excluir disciplina:", error);
        alert("Não foi possível excluir. Podem existir matrículas ativas.");
      }
    }
  };

  const columns = [
    { key: "id" as keyof Disciplina, label: "ID" },
    { key: "nome" as keyof Disciplina, label: "Nome da Disciplina" },
    { key: "cargaHoraria" as keyof Disciplina, label: "Carga Horária (h)" },
    { 
      key: "professor" as keyof Disciplina, 
      label: "Professor",
      render: (item: Disciplina) => item.professor?.nome || <span className="text-slate-400 italic">Sem professor</span>
    },
  ];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Gestão de Disciplinas</h1>
          <p className="text-slate-500 mt-1">Gira as disciplinas e suas atribuições de professores.</p>
        </div>
        <button
          onClick={() => handleOpenModal()}
          className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white font-medium rounded-xl hover:bg-indigo-700 transition-all focus:ring-2 focus:ring-offset-2 focus:ring-indigo-600"
        >
          <Plus className="w-4 h-4" />
          <span>Nova Disciplina</span>
        </button>
      </div>

      <DataTable
        data={disciplinas}
        columns={columns}
        isLoading={isLoading}
        onEdit={handleOpenModal}
        onDelete={handleDelete}
      />

      <FormModal
        isOpen={isModalOpen}
        onClose={handleCloseModal}
        title={editingDisciplina ? "Editar Disciplina" : "Nova Disciplina"}
      >
        <form onSubmit={handleSubmit} className="space-y-5">
          <div className="space-y-1">
            <label htmlFor="nome" className="block text-sm font-medium text-slate-700">Nome da Disciplina</label>
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
            <label htmlFor="cargaHoraria" className="block text-sm font-medium text-slate-700">Carga Horária (horas)</label>
            <input
              type="number"
              id="cargaHoraria"
              required
              min="1"
              value={formData.cargaHoraria}
              onChange={(e) => setFormData({ ...formData, cargaHoraria: e.target.value })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
            />
          </div>
          <div className="space-y-1">
            <label htmlFor="professor" className="block text-sm font-medium text-slate-700">Professor Responsável (Opcional)</label>
            <select
              id="professor"
              value={formData.professor.id}
              onChange={(e) => setFormData({ ...formData, professor: { id: e.target.value } })}
              className="w-full px-4 py-2.5 rounded-xl border border-slate-200 bg-slate-50 focus:bg-white focus:ring-2 focus:ring-indigo-600/20 focus:border-indigo-600 transition-all outline-none"
            >
              <option value="">Selecione um professor...</option>
              {professores.map((prof) => (
                <option key={prof.id} value={prof.id}>{prof.nome}</option>
              ))}
            </select>
          </div>
          <div className="pt-4 flex gap-3">
            <button type="button" onClick={handleCloseModal} className="flex-1 px-4 py-2.5 text-slate-700 bg-slate-100 hover:bg-slate-200 font-medium rounded-xl transition-colors">
              Cancelar
            </button>
            <button type="submit" className="flex-1 px-4 py-2.5 text-white bg-indigo-600 hover:bg-indigo-700 font-medium rounded-xl shadow-sm hover:shadow-md transition-all">
              {editingDisciplina ? "Guardar" : "Criar"}
            </button>
          </div>
        </form>
      </FormModal>
    </div>
  );
}
