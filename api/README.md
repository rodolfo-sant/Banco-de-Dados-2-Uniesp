# 🎓 Aluno Online - API RESTful

Uma API robusta desenvolvida em Java com Spring Boot para o gerenciamento acadêmico. Este projeto foi construído para facilitar o controle de alunos, professores, disciplinas e matrículas, servindo como núcleo backend para aplicações educacionais com regras de negócio completas para lançamento de notas e status de alunos.

---

## 📖 Explicação do Projeto

O sistema **Aluno Online** é uma aplicação backend focada não apenas em operações de CRUD (Create, Read, Update, Delete), mas também em regras de negócio complexas do dia a dia acadêmico. O objetivo principal é garantir o armazenamento seguro, a validação estruturada e a manipulação eficiente dos dados de uma instituição de ensino.

O projeto foi desenvolvido focando nas boas práticas de desenvolvimento backend, garantindo que o código seja limpo, escalável e de fácil manutenção.

---

## ⚙️ Descrição da Arquitetura Utilizada

A aplicação foi estruturada seguindo o padrão de **Arquitetura em Camadas** (Layered Architecture), o que garante um excelente nível de desacoplamento. As camadas se dividem da seguinte forma:

1. **Model (Entidades):** Representação das tabelas no banco de dados. É aqui que definimos as colunas e os relacionamentos (como `@ManyToOne` entre Disciplina e Professor, e entre Matrícula, Aluno e Disciplina).
2. **Repository (Persistência):** Interfaces que herdam do Spring Data JPA, responsáveis por realizar toda a comunicação direta com o banco de dados PostgreSQL sem a necessidade de escrever SQL manualmente.
3. **Service (Regra de Negócio):** Camada central onde toda a lógica da aplicação acontece. Ela atua como uma ponte entre o banco de dados e os controladores, realizando validações (como cálculo de médias e status de aprovação/reprovação).
4. **Controller (Endpoints):** A porta de entrada da API. Responsável por receber as requisições HTTP (GET, POST, PUT, PATCH, DELETE), encaminhar para os Services e devolver as respostas adequadas ao cliente.

---

## 📂 Detalhamento do Código e Evolução

A organização dos pacotes da aplicação reflete diretamente a arquitetura escolhida, separando as responsabilidades de forma clara e escalável:

```text
src/main/java/br/com/alunoonline/api/
 ├── controller/    # AlunoController, ProfessorController, DisciplinaController e MatriculaAlunoController
 ├── service/       # Lógica de negócio, incluindo cálculo de notas e alteração de status
 ├── repository/    # Interfaces de comunicação com o banco de dados
 └── model/         # Entidades JPA (Aluno, Professor, Disciplina, MatriculaAluno)
```

🛣️ Principais Rotas e Funcionalidades Implementadas:
Cadastros Básicos (Alunos, Professores e Disciplinas):

POST: Criação de novos registros (/alunos, /professores, /disciplinas).

GET: Listagem geral e busca por ID de todos os cadastros.

PUT: Atualização completa de cadastros existentes.

DELETE: Remoção de registros do banco de dados.

Gestão de Matrículas e Notas (Regras de Negócio):

POST /matriculas-alunos: Realiza a matrícula de um aluno em uma disciplina específica (iniciando com status "MATRICULADO").

PATCH /matriculas-alunos/atualizar-notas/{id}: Permite o lançamento da Nota 1 e Nota 2 do aluno. O sistema calcula a média automaticamente e define o status como "APROVADO" ou "REPROVADO".

PATCH /matriculas-alunos/trancar/{id}: Altera o status da matrícula do aluno para "TRANCADO".

🛠️ Tecnologias Utilizadas
Java

Spring Boot (Web, Data JPA)

PostgreSQL (Banco de dados relacional)

Lombok (Redução de boilerplate de código)

Maven (Gerenciamento de dependências)

Insomnia / Postman (Teste de rotas da API)

## 📸 Testes e Demonstração

### 1. Requisições no Insomnia
**Criando um Aluno (POST):**
<img width="1919" height="1029" alt="CriarAlunoDepois" src="https://github.com/user-attachments/assets/138d70b5-b1f9-43be-a29d-bc9ce0af3d89" />

**Listando Todos Professores (GET):**
<img width="1919" height="1034" alt="ListarTodosProfessores" src="https://github.com/user-attachments/assets/6a18a6d1-0d03-49d7-9497-156db2bc7ede" />

**Listando Aluno Por Id(GET):**
<img width="1919" height="1030" alt="BuscarAlunoPorId" src="https://github.com/user-attachments/assets/a2b5d56e-d442-4711-a7a3-64c8a5aabd30" />


**Atualizando um Aluno (PUT):**
<img width="1919" height="1030" alt="AtualizarAlunoPorIdDepois" src="https://github.com/user-attachments/assets/ad224da1-fed1-4aad-b08a-e68ad85df42f" />


**Deletando um Professor (DELETE):**
<img width="1919" height="1027" alt="DeletarProfessorPorIdDepois" src="https://github.com/user-attachments/assets/a202f652-77a5-44b0-a7b5-0116fea0e4b2" />


### 2. Persistência no DBeaver (PostgreSQL)
**Tabela de Alunos Atualizada Depois De Testes:**
<img width="1919" height="1031" alt="TabelaBdAlunoAtualizada" src="https://github.com/user-attachments/assets/d37ea042-2fa5-4c85-b510-ea7f40a948c2" />


**Tabela de Professores Atualizada Depois De Testes:**
<img width="1919" height="1034" alt="TabelaBdProfessorAtualizada" src="https://github.com/user-attachments/assets/b3101420-c27d-47ca-9e05-a190dd795425" />

📸 Testes e Demonstração
1. Requisições no Insomnia
**Criando uma Disciplina (POST):**
<img width="1919" height="1032" alt="CriarDisciplina" src="https://github.com/user-attachments/assets/4403d30b-4b5f-4ea4-bc4e-810efec4de57" />

**Listando Todas as Disciplinas (GET):**
<img width="1919" height="1030" alt="ListarTodasAsDisciplinas" src="https://github.com/user-attachments/assets/42ce8f80-97d6-4098-a25c-8ebf0695daf8" />

**Listando Disciplina Por Id (GET):**
<img width="1919" height="1034" alt="BuscarDisciplinaPorId" src="https://github.com/user-attachments/assets/75b4fdea-5935-4152-bd50-9d733ec6863e" />

**Atualizando uma Disciplina (PUT):**
<img width="1919" height="1032" alt="AtualizarDisciplinaPorID" src="https://github.com/user-attachments/assets/f076f679-58cf-48e6-8cf7-420ca3d07e40" />

**Deletando uma Disciplina (DELETE):**
<img width="1919" height="1033" alt="DeletarDisciplinaPorID" src="https://github.com/user-attachments/assets/451028d8-582d-4f5d-84bb-6a4bdcbc7c0c" />

**Criando uma Matricula (POST):**
<img width="1919" height="1035" alt="CriarMatricula" src="https://github.com/user-attachments/assets/016a4721-ee7c-46f9-b05f-19c0dcaea876" />

**Trancando uma Matricula (PATCH):**
<img width="1919" height="1036" alt="TrancarMatricula" src="https://github.com/user-attachments/assets/b05b0f12-ac5d-4bd7-9f8e-15816ffeb129" />

**Atualizando uma Matricula (PATCH):**
<img width="1919" height="1033" alt="AtualizarMatricula" src="https://github.com/user-attachments/assets/1460c4de-4f7b-4d37-9863-8bebd1c6828e" />

💡 Nota: A API agora também conta com testes bem-sucedidos para as rotas de criação de Disciplina e lançamento de notas na entidade MatriculaAluno.

2. Persistência no DBeaver (PostgreSQL)
Tabela de Disciplinas Atualizada Depois De Testes:
<img width="1919" height="1032" alt="Disciplina" src="https://github.com/user-attachments/assets/42466259-37be-4c52-a002-1b4d1767df3e" />

Tabela de Matriculas Atualizada Depois De Testes:
<img width="1919" height="1032" alt="Matricula" src="https://github.com/user-attachments/assets/0fe8d17e-dd1f-46a4-877d-76b3de3e270b" />

## 👨‍💻 Autor
Rodolfo Santiago Romero  Garcia
Ciência da Computação - UNIESP
