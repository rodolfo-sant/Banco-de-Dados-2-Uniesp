import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Sidebar from "@/components/Sidebar";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Aluno Online - Gestão Académica",
  description: "Sistema integrado de gestão escolar e acadêmica",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="pt-PT" className="antialiased">
      <body className={`${inter.className} bg-slate-50 text-slate-900 min-h-screen flex`}>
        {/* Sidebar fixa à esquerda */}
        <Sidebar />
        
        {/* Área principal de conteúdo (com margem para acomodar a sidebar) */}
        <main className="flex-1 ml-[72px] md:ml-64 min-h-screen transition-all duration-300">
          <div className="p-8 max-w-7xl mx-auto">
            {children}
          </div>
        </main>
      </body>
    </html>
  );
}
