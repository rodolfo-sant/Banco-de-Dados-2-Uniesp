"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  GraduationCap,
  Users,
  BookOpen,
  FileBarChart,
  ChevronLeft,
  ChevronRight,
} from "lucide-react";
import { useState } from "react";

// ═══════════════════════════════════════════════════════════════════════════
// Itens de navegação da sidebar
// ═══════════════════════════════════════════════════════════════════════════
const navItems = [
  { href: "/", label: "Dashboard", icon: LayoutDashboard },
  { href: "/alunos", label: "Alunos", icon: GraduationCap },
  { href: "/professores", label: "Professores", icon: Users },
  { href: "/disciplinas", label: "Disciplinas", icon: BookOpen },
  { href: "/relatorios", label: "Relatórios", icon: FileBarChart },
];

export default function Sidebar() {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = useState(false);

  return (
    <aside
      className={`
        fixed left-0 top-0 z-40 h-screen
        bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900
        border-r border-slate-700/50
        transition-all duration-300 ease-in-out
        flex flex-col
        ${collapsed ? "w-[72px]" : "w-64"}
      `}
    >
      {/* ─── Logo / Branding ──────────────────────────────────── */}
      <div className="flex items-center gap-3 px-5 py-6 border-b border-slate-700/50">
        <div className="flex-shrink-0 w-9 h-9 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-lg flex items-center justify-center shadow-lg shadow-indigo-500/25">
          <GraduationCap className="w-5 h-5 text-white" />
        </div>
        {!collapsed && (
          <div className="overflow-hidden">
            <h1 className="text-lg font-bold text-white tracking-tight">
              Aluno Online
            </h1>
            <p className="text-[10px] text-slate-400 uppercase tracking-widest">
              Gestão Académica
            </p>
          </div>
        )}
      </div>

      {/* ─── Navegação ────────────────────────────────────────── */}
      <nav className="flex-1 px-3 py-4 space-y-1 overflow-y-auto">
        {navItems.map(({ href, label, icon: Icon }) => {
          const isActive =
            href === "/" ? pathname === "/" : pathname.startsWith(href);

          return (
            <Link
              key={href}
              href={href}
              className={`
                group flex items-center gap-3 px-3 py-2.5 rounded-xl
                text-sm font-medium transition-all duration-200
                ${
                  isActive
                    ? "bg-indigo-500/15 text-indigo-400 shadow-sm shadow-indigo-500/10"
                    : "text-slate-400 hover:bg-slate-700/50 hover:text-white"
                }
              `}
              title={collapsed ? label : undefined}
            >
              <Icon
                className={`w-5 h-5 flex-shrink-0 transition-colors ${
                  isActive
                    ? "text-indigo-400"
                    : "text-slate-500 group-hover:text-white"
                }`}
              />
              {!collapsed && <span>{label}</span>}
              {isActive && !collapsed && (
                <div className="ml-auto w-1.5 h-1.5 bg-indigo-400 rounded-full animate-pulse" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* ─── Botão de colapsar ─────────────────────────────────── */}
      <div className="px-3 py-4 border-t border-slate-700/50">
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="flex items-center justify-center w-full gap-2 px-3 py-2 text-xs text-slate-500 rounded-lg hover:bg-slate-700/50 hover:text-white transition-colors"
        >
          {collapsed ? (
            <ChevronRight className="w-4 h-4" />
          ) : (
            <>
              <ChevronLeft className="w-4 h-4" />
              <span>Recolher</span>
            </>
          )}
        </button>
      </div>
    </aside>
  );
}
