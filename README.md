# TesterLoop (nome provisório)

Marketplace de troca de testes para cumprir o requisito de **teste fechado do Google Play** (12 testadores × 14 dias contínuos), com verificação de instalação e uso diário via SDK.

## Estrutura do Monorepo

| Caminho | Conteúdo |
|---|---|
| [`apps/hub`](./apps/hub) | App Hub em Flutter (Android + Console Web responsivo) e módulo nativo Kotlin (`TokenProvider`, `TrackedAppsScanner`) |
| [`apps/landing`](./apps/landing) | Landing page Astro estática (EN + PT-BR), guias SEO/AEO, docs do SDK e `/llms.txt` |
| [`packages/sdk-android`](./packages/sdk-android) | SDK Android nativo em Kotlin (`androidx.startup` + `ProcessLifecycleOwner`, zero código obrigatório) |
| [`packages/sdk-flutter`](./packages/sdk-flutter) | Plugin Flutter `testerloop` (somente Android; no-op em outras plataformas) |
| [`packages/shared-contracts`](./packages/shared-contracts) | OpenAPI v1 e JSON Schema do JWT ES256 |
| [`backend/supabase`](./backend/supabase) | Migrations Postgres, RLS, RPCs, `pg_cron` (expiração em 360 dias), Edge Functions Deno e `docker-compose.vps.yml` |
| [`tasks/`](./tasks) | PRDs do projeto ([`prd-master.md`](./tasks/prd-master.md)) |

## Documentação Original

| Documento | Conteúdo |
|---|---|
| [PRD.md](./PRD.md) | Problema, personas, escopo, jornadas, economia de pontos, Featured, métricas, riscos, roadmap e decisões OQ |
| [SPEC.md](./SPEC.md) | Arquitetura, modelo de dados, protocolo SDK↔Hub↔Backend, SDK Kotlin, plugin Flutter, app Hub, Featured/billing, antifraude e SEO/AEO |
| [SDK_AI_INSTALL.md](./SDK_AI_INSTALL.md) | Rascunho da doc de instalação do SDK "AI-ready" |

## Verificação Local

```bash
# Plugin Flutter
cd packages/sdk-flutter && flutter pub get && flutter test

# App Hub Flutter
cd apps/hub && flutter pub get && flutter analyze && flutter test

# Landing Astro
cd apps/landing && npm ci && npm run build
```
