# PRD: TesterLoop MVP (Plataforma de Troca de Testes Google Play)

> **Status:** Em execução · **Versão:** 1.0 · **Data:** 2026-11-13  
> **Referências:** [`PRD.md`](../PRD.md) · [`SPEC.md`](../SPEC.md) · [`SDK_AI_INSTALL.md`](../SDK_AI_INSTALL.md)

---

## 1. Introduction/Overview

Contas de desenvolvedor **pessoais** no Google Play criadas após 13/11/2023 exigem um teste fechado com pelo menos **12 testadores inscritos continuamente por 14 dias** antes de liberar o pedido de acesso à produção.

O **TesterLoop** (nome provisório, **❓ OQ-18**) resolve esse gargalo por meio de um marketplace recíproco baseado em pontos com **verificação real de instalação e uso diário via SDK**:
- Desenvolvedores testam apps de outros devs para acumular pontos (≥ 60s/dia em foreground por 14 dias contínuos).
- Com pontos acumulados, publicam suas próprias campanhas de teste fechado (12 vagas + 3 reserva = 15 vagas).
- Um **SDK leve em Kotlin** (e plugin Flutter) valida handshake via `ContentProvider` (`callingPackage`) + certificado SHA-256 + origem Play Store, sem coletar PII.
- O backend roda em **Supabase self-hosted em VPS** (**OQ-17**), os pontos expiram em **360 dias** sem atividade (**OQ-7**), o próprio Hub será publicado em **conta pessoal** usando `reddit.com/r/AndroidAppTesters` para tração inicial (**OQ-15**), e a aquisição orgânica é impulsionada por uma **landing page Astro SEO/AEO** com docs AI-ready (`/llms.txt`).

---

## 2. Goals

- Estruturar o monorepo completo (`apps/hub`, `apps/landing`, `packages/sdk-android`, `packages/sdk-flutter`, `packages/shared-contracts`, `backend/supabase`).
- Entregar schema Postgres completo com ledger imutável, RLS, RPCs atômicas e jobs `pg_cron` prontos para Supabase self-hosted em VPS.
- Implementar todas as Edge Functions (`/sdk/v1/*`, `/hub/v1/*`, `/billing/v1/*`).
- Implementar o SDK Android Kotlin zero-code (`androidx.startup` + `ProcessLifecycleOwner` + fila JSONL) e o plugin Flutter `testerloop` (no-op em não-Android).
- Construir o App Hub Flutter com design system dark-first, módulo nativo Android (`TokenProvider`, `TrackedAppsScanner`), jornada completa do testador e jornada completa do desenvolvedor (incluindo validação SDK em 2 etapas, relatório Markdown para o Play Console, reserva Featured e exclusão de conta).
- Publicar landing page estática Astro SEO/AEO bilíngue (`en` + `pt-BR`) com guias, docs do SDK e `llms.txt`/`llms-full.txt`.
- Garantir qualidade automatizada com CI no GitHub Actions (`flutter analyze`, `flutter test`, `npm run build`).

---

## 3. User Stories (Steps de Implementação)

### US-001: Estrutura do Monorepo e Contratos da API
**Description:** As a developer, I want a Melos monorepo and formal OpenAPI/JSON schemas so that SDK, Hub, and backend share unambiguous contracts.

**Acceptance Criteria:**
- [ ] `melos.yaml` na raiz orquestrando `packages/sdk-flutter` e `apps/hub`
- [ ] `packages/shared-contracts/openapi-v1.yaml` cobrindo `/sdk/v1/*`, `/hub/v1/*` e `/billing/v1/*`
- [ ] `packages/shared-contracts/schemas/tracking-token.schema.json` validando JWT ES256 (`iss`, `aud`, `sub`, `pkg`, `kind`, `tz`, `iat`, `exp`)

---

### US-002: Schema SQL, RLS, RPCs e Jobs `pg_cron` no Supabase Self-Hosted (VPS)
**Description:** As a system architect, I want the complete Postgres schema, RLS policies, atomic RPCs, and `pg_cron` jobs configured for self-hosted VPS deployment so that points ledger and campaigns remain consistent and low-cost.

**Acceptance Criteria:**
- [ ] `backend/supabase/config.toml`, `docker-compose.vps.yml` e `README.md` com instruções de VPS, TLS e backup `pg_dump`
- [ ] Migration inicial criando todas as tabelas na ordem correta de FK (`profiles`, `devices`, `apps`, `campaigns`, `enrollments`, `daily_activity`, `sdk_events` particionada, `points_ledger`, view `wallet`, `feedback`, `featured_products`, `purchases`, `featured_bookings` com `EXCLUDE USING gist`, `config`, `abuse_reports`) e triggers de contadores
- [ ] Migration de RLS + RPCs `security definer` (`publish_campaign`, `cancel_campaign` com reembolso proporcional, `enroll_in_campaign`, `submit_feedback`, `delete_user_account`)
- [ ] Migration de jobs `pg_cron` incluindo `rollup_days`, `complete_enrollments`, `complete_campaigns`, `expire_points` (**360 dias** sem atividade — OQ-7) e `featured_rotation`
- [ ] `backend/supabase/seed.sql` populando `config`, produtos Featured e link comunitário `r/AndroidAppTesters`

---

### US-003: Edge Functions do SDK, Hub e Billing
**Description:** As a mobile client and SDK, I want Deno/TypeScript Edge Functions to issue ES256 tracking tokens, verify handshakes/events, record daily presence, and validate Play Billing purchases.

**Acceptance Criteria:**
- [ ] Helpers em `_shared/` (`cors.ts`, `jwt.ts` ES256 com Web Crypto, `supabase.ts`)
- [ ] Endpoints SDK: `sdk-handshake`, `sdk-events` (idempotência por `event.id`), `sdk-config` (kill-switch)
- [ ] Endpoints Hub: `hub-device-register`, `hub-tracking-token`, `hub-presence`
- [ ] Endpoints Billing: `billing-verify` (`GET` quote + `POST` verify) e `billing-rtdn`

---

### US-004: SDK Android Nativo em Kotlin com Auto-Init e Handshake
**Description:** As a host Android developer, I want a zero-code Kotlin SDK (< 50 KB, no heavy dependencies) so that integrating TesterLoop requires only 1 Gradle dependency and 1 `<meta-data>` tag.

**Acceptance Criteria:**
- [ ] `AndroidManifest.xml` com `INTERNET`, `<queries>` para `io.testerloop.hub.token`, `EntryActivity` (`io.testerloop.action.OPEN`) e `InitializationProvider`
- [ ] `TesterLoopInitializer`, `EntryActivity`, `TokenStore`, `HubTokenClient`, `AppInfo`, `EventQueue` (FIFO JSONL máx 500), `ApiClient` (`HttpURLConnection` + `runCatching`), `SessionTracker` (`ProcessLifecycleOwner`)
- [ ] API opcional `TesterLoop.init`, `TesterLoop.status`, `TesterLoop.setEnabled`
- [ ] Testes unitários Kotlin para fila `EventQueue` e serialização de eventos

---

### US-005: Plugin Flutter `testerloop` com No-Op Multiplataforma
**Description:** As a Flutter developer, I want `flutter pub add testerloop` to automatically merge the Android SDK and remain a safe no-op on iOS, Web, and Desktop.

**Acceptance Criteria:**
- [ ] `packages/sdk-flutter/pubspec.yaml` declarando apenas plataforma Android
- [ ] `lib/testerloop.dart` com `TesterLoop.status()` e `TesterLoop.setEnabled(bool)` seguros em não-Android
- [ ] `android/build.gradle` e `TesterLoopPlugin.kt` integrando `MethodChannel('io.testerloop/sdk')`
- [ ] Testes unitários Flutter validados com `flutter analyze` e `flutter test`

---

### US-006: App Hub Flutter — Fundação, Módulo Nativo, Design System e Autenticação
**Description:** As a user, I want an Android Hub app (and responsive Flutter Web console) with dark-first UI, secure native token provider, and Google Sign-In onboarding.

**Acceptance Criteria:**
- [ ] Projeto `apps/hub` com módulo nativo Kotlin (`TokenProvider` verificando `callingPackage`, `TrackedAppsScanner` usando `queryIntentActivities`, `HubNativePlugin`)
- [ ] Design System dark-first (`app_tokens.dart`, `app_theme.dart`) com contraste WCAG AA, tipografia tabular (`tabularFigures`) e suporte i18n `pt-BR` / `en`
- [ ] Modelos imutáveis e `HubController` conectado a repositório híbrido (Supabase + modo local/demo testável)
- [ ] Tela `/onboarding` com 3 slides explicativos, login Google Sign-In e verificação Play Integrity (+10 pts)
- [ ] Touch targets ≥ 48×48dp, estados de loading/erro explícitos, `flutter analyze` e `flutter test` passando

---

### US-007: App Hub Flutter — Jornada do Testador
**Description:** As a tester, I want to discover campaigns, complete the 4-step enrollment flow, track my 14-day progress, submit feedback, and inspect my points wallet.

**Acceptance Criteria:**
- [ ] `/discover`: Carrossel **Featured (3 slots)** + abas **Recentes** e **Quase completos** + busca/filtro por categoria
- [ ] `/c/:id`: Detalhes da campanha, certificado verificado, progresso `x/12`, regra 60s/dia × 14 dias e CTA "Quero testar"
- [ ] `/c/:id/join`: Stepper guiado de 4 passos (Google Group → Opt-in Play → Instalar com detecção local → Abrir e validar handshake)
- [ ] `/tests`: Cards com calendário de 14 dias (`✓`, `⚠`, `✗`), timer de sessão ≥ 60s e envio de feedback estruturado (+2 pts)
- [ ] `/wallet`: Saldo Disponível × Pendente, barra rumo a 120 pts, aviso de expiração em 360 dias e extrato do ledger
- [ ] Widget tests cobrindo descoberta, inscrição e carteira + `flutter analyze` limpo

---

### US-008: App Hub Flutter — Jornada do Desenvolvedor, Relatório Play Console, Featured e Settings
**Description:** As a developer publishing an app, I want to register my app, validate the SDK in 2 steps, publish a 12×14 campaign, book Featured slots, export the Play Console report, and manage account settings.

**Acceptance Criteria:**
- [ ] `/apps` e `/apps/new`: Listagem e cadastro de app (nome, `package_name`, descrição ≤ 80 chars, URL de opt-in)
- [ ] `/apps/:id`: Exibição de `appKey`, cópia do prompt AI-ready, validação SDK em 2 etapas (Debug + Teste Fechado Play TOFU), publicação (debita 120 pts), cancelamento proporcional e painel da campanha
- [ ] Modal **Relatório para Acesso à Produção** exportando Markdown estruturado com métricas verificadas e feedbacks reais
- [ ] `/apps/:id/featured`: Reserva e compra de slot Featured (24h/72h/7d) nos 3 slots
- [ ] `/settings`: Troca de idioma (`pt-BR`/`en`), lembrete diário às 19h, reputação, link para `reddit.com/r/AndroidAppTesters` (OQ-15) e exclusão de conta (H13)
- [ ] Layout responsivo com `NavigationRail` para Console Web (`OQ-2`) em telas largas
- [ ] Widget tests da jornada dev + `flutter analyze` e `flutter test` passando

---

### US-009: Landing Page Astro SEO/AEO, Guias, Docs do SDK e `llms.txt`
**Description:** As a prospective developer searching Google or AI assistants, I want a fast static landing page with guides, SDK installation docs, `llms.txt`, and Play-required legal pages.

**Acceptance Criteria:**
- [ ] Projeto Astro estático em `apps/landing` com `canonical`, `hreflang` (`en`/`pt-BR`/`x-default`) e JSON-LD (`Organization`, `SoftwareApplication`, `FAQPage`, `Article`)
- [ ] Home `/` (EN) e `/pt-br/` (PT-BR) com proposta de valor, fluxo, comparativo, Featured e link `r/AndroidAppTesters`
- [ ] Guias AEO com bloco TL;DR (`/guides/12-testers-14-days-google-play`, `/guides/closed-testing-step-by-step`, `/guides/production-access-questionnaire`)
- [ ] Docs do SDK (`/docs/sdk/android`, `/docs/sdk/flutter`) e arquivos `/llms.txt`, `/llms-full.txt`, `/robots.txt` (liberando crawlers de IA)
- [ ] Páginas legais `/privacy`, `/terms`, `/delete-account`
- [ ] `npm install && npm run build` sem erros gerando todas as rotas estáticas

---

### US-010: Pipeline CI/CD do Monorepo
**Description:** As a maintainer, I want an automated GitHub Actions workflow so that every PR and push validates Flutter, SDK, landing build, and backend artifacts.

**Acceptance Criteria:**
- [ ] `.github/workflows/ci.yml` executando `flutter test` em `packages/sdk-flutter`, `flutter analyze` + `flutter test` em `apps/hub`, `npm ci && npm run build` em `apps/landing` e checagem estrutural de `backend/supabase`
- [ ] `README.md` na raiz atualizado com guia rápido de cada componente

---

## 4. Functional Requirements

- **FR-1:** O sistema deve exigir **14 dias contínuos** e mínimo de **10 dias ativos** (≥ 60s em foreground) para concluir uma inscrição (configurável em `config`).
- **FR-2:** Cada campanha deve oferecer **12 vagas principais + 3 vagas de reserva** (15), custando **120 pontos** para publicar.
- **FR-3:** O testador recebe **1 ponto pendente por dia ativo**, liberado como disponível na conclusão junto com **+3 pontos de bônus**, e **+2 pontos** por feedback aprovado.
- **FR-4:** Novos dispositivos aprovados no Play Integrity recebem **+10 pontos de boas-vindas**.
- **FR-5:** Pontos disponíveis expiram após **360 dias** sem atividade no ledger (**OQ-7**).
- **FR-6:** O SDK não deve coletar PII (sem e-mail, advertising ID ou localização); vinculação ao testador ocorre apenas via JWT opaco ES256 e `callingPackage` no `TokenProvider`.
- **FR-7:** A publicação de campanha só é liberada após a **Etapa 2 da validação do SDK** (build instalada via Google Play com gravação TOFU do `signing_cert_sha256`).
- **FR-8:** O próprio Hub será publicado em **conta pessoal** utilizando `reddit.com/r/AndroidAppTesters` como canal inicial de auxílio e recrutamento de testadores (**OQ-15**).
- **FR-9:** O backend roda integralmente em **Supabase self-hosted em VPS** (**OQ-17**).

---

## 5. Non-Goals (Out of Scope)

- Suporte a iOS / Apple TestFlight.
- Venda direta de pontos no MVP (monetização apenas via 3 slots Featured).
- Automação não oficial no Google Play Console para adicionar/remover e-mails.
- Garantia contratual de aprovação de acesso à produção pelo Google.
- Leilão de segundo preço para Featured (previsto apenas para Fase 3).

---

## 6. Design Considerations

- **Source of the guidance:** `ui-ux-pro-max` / `agent-choice` (design system próprio definido em `apps/hub/lib/core/theme/app_tokens.dart`, pois não havia design system pré-existente no repo).
- **Style & visual direction:** **Developer Trust & Precision** — interface dark-first limpa, inspirada em ferramentas modernas de engenharia (Linear / Raycast / Supabase Studio), evitando gradientes neon excessivos ou "AI slop".
- **Color palette:**
  - Fundo principal: `#0B0F17` (`AppColors.bgPrimary`)
  - Superfície cards: `#111827` (`AppColors.surface`) e `#1E293B` (`AppColors.surfaceElevated`)
  - Borda sutil: `#263244` (`AppColors.border`)
  - Primária (ação): Indigo `#6366F1` (`AppColors.primary`)
  - Sucesso / SDK verificado: Emerald `#10B981` (`AppColors.success`)
  - Alerta / `at_risk`: Amber `#F59E0B` (`AppColors.warning`)
  - Erro / `dropped`: Red `#EF4444` (`AppColors.danger`)
  - Texto principal `#F8FAFC`, texto secundário `#94A3B8`.
- **Typography:** Fonte sans-serif limpa para títulos e corpo + números tabulares (`FontFeature.tabularFigures()`) em contadores `x/12`, streaks `14d`, timers de `60s` e `appKey` monoespaçada.
- **UX rules to enforce:**
  - Todos os botões e chips interativos com área mínima de toque `48×48dp`.
  - Contraste mínimo WCAG AA (≥ 4.5:1 em textos).
  - Feedback imediato em ações assíncronas (spinners/snackbars claros), empty states acionáveis com CTA e confirmação explícita para ações destrutivas (cancelar campanha, excluir conta).
- **Existing components to reuse:** Criação inicial do kit reutilizável (`AppStatusPill`, `AppProgressRing`, `SectionCard`, `StreakCalendarGrid`) centralizado no módulo `core/widgets/`.

---

## 7. Technical Considerations

- **Monorepo:** Melos + Gradle (`sdk-android`) + npm/Astro (`landing`) + Supabase CLI/Docker (`backend/supabase`).
- **Segurança no Android:** `TokenProvider` valida `getCallingPackage()` para impedir que um app testado leia tokens de outro app.
- **Confiabilidade do SDK:** Sem dependências externas além de `androidx.startup` e `androidx.lifecycle:lifecycle-process`; `HttpURLConnection` nativo e `runCatching` em toda a superfície pública e interna.
- **Resiliência no Hub:** Suporte a configuração via `--dart-define=SUPABASE_URL` e `SUPABASE_ANON_KEY`, com fallback local/demo determinístico quando executado offline ou em testes automatizados.

---

## 8. Success Metrics

- Tempo mediano até preencher 12 vagas ≤ 72h após lançamento.
- Taxa de conclusão de campanha (≥ 12 testadores × 14 dias) ≥ 80%.
- Taxa de validação do SDK na primeira tentativa ≥ 90%.
- `flutter analyze` com 0 issues, 100% dos testes unitários/widget passando e Lighthouse ≥ 95 na landing Astro.

---

## 9. Open Questions (Não bloqueantes para implementação)

- **❓ OQ-9:** Definir preços finais dos blocos Featured (`24h`, `72h`, `7d`) antes de configurar os SKUs no Google Play Console (referência adotada no código/seed: US$ 4,99 / US$ 11,99 / US$ 24,99).
- **❓ OQ-18:** Definir nome definitivo da marca, domínio e package/groupId (`TesterLoop` e `io.testerloop` usados como placeholders isolados em constantes/configs).
- **❓ TQ-1..TQ-10:** Confirmar preferências finais de infraestrutura (Riverpod vs Stateful/ChangeNotifier no MVP, Analytics PostHog, texto exato de política de reembolso proporcional `TQ-6` e domínio Cloudflare Pages `TQ-8`).
