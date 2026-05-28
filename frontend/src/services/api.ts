// ============================================================================
// SERVIÇO CENTRALIZADO DE API — Aluno Online Frontend
// ============================================================================
// Pré-configurado para apontar ao Spring Boot (localhost:8080)
// Inclui interceptors para logging e tratamento de erros
//
// CORS: Se houver erros de CORS, adicionar ao Spring Boot:
//   @CrossOrigin(origins = "http://localhost:3000")
//   nos controllers, ou configurar globalmente via WebMvcConfigurer:
//
//   @Bean
//   public WebMvcConfigurer corsConfigurer() {
//       return new WebMvcConfigurer() {
//           @Override
//           public void addCorsMappings(CorsRegistry registry) {
//               registry.addMapping("/**")
//                   .allowedOrigins("http://localhost:3000")
//                   .allowedMethods("GET","POST","PUT","PATCH","DELETE","OPTIONS");
//           }
//       };
//   }
// ============================================================================

import axios from "axios";

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080",
  timeout: 15000,
  headers: {
    "Content-Type": "application/json",
  },
});

// ─── Interceptor de Request: logging em dev ────────────────────────
api.interceptors.request.use(
  (config) => {
    if (process.env.NODE_ENV === "development") {
      console.log(`[API] ${config.method?.toUpperCase()} ${config.url}`);
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// ─── Interceptor de Response: tratamento centralizado de erros ─────
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response) {
      // O servidor respondeu com status de erro
      const status = error.response.status;
      const message =
        error.response.data?.message || error.response.statusText;

      console.error(`[API Error] ${status}: ${message}`);

      if (status === 404) {
        console.warn("[API] Recurso não encontrado");
      } else if (status === 500) {
        console.error("[API] Erro interno do servidor");
      }
    } else if (error.request) {
      // A requisição foi feita mas não houve resposta (servidor offline ou CORS)
      console.error(
        "[API] Sem resposta do servidor. Verifique se o Spring Boot está em execução e se o CORS está configurado."
      );
    }
    return Promise.reject(error);
  }
);

export default api;
