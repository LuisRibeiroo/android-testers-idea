# PRD Master Tracker — TesterLoop

> Registro vivo dos PRDs, telas e pontos em aberto do projeto.

## PRDs

| Documento | Escopo | Status |
|---|---|---|
| [`prd-testerloop-mvp.md`](./prd-testerloop-mvp.md) | MVP completo (Contratos, Backend Supabase VPS, SDK Kotlin, Plugin Flutter, Hub App, Landing Astro, CI) | Em execução |

## Screen Registry (App Hub Flutter)

| Rota | Tela | Feature | Status |
|---|---|---|---|
| `/onboarding` | Onboarding + Google Sign-In + Play Integrity | `auth` | Pendente |
| `/discover` | Featured (3 slots) + Recentes + Quase completos | `discover` | Pendente |
| `/c/:id` | Detalhe da campanha | `campaign_detail` | Pendente |
| `/c/:id/join` | Stepper 4 passos de inscrição | `enrollment` | Pendente |
| `/tests` | Meus testes (calendário 14 dias + feedback) | `enrollment` | Pendente |
| `/wallet` | Carteira (disponível, pendente, expiração 360d, extrato) | `wallet` | Pendente |
| `/apps` | Meus apps + modal `/apps/new` | `my_apps` | Pendente |
| `/apps/:id` | Detalhe do app, validação SDK, publicar, relatório Play | `my_apps` | Pendente |
| `/apps/:id/featured` | Reserva e compra de slot Featured | `featured` | Pendente |
| `/settings` | Idioma, lembrete 19h, reputação, Reddit r/AndroidAppTesters, excluir conta | `settings` | Pendente |

## Open Questions

| ID | Descrição | Default adotado na implementação |
|---|---|---|
| **OQ-9** | Preços finais Featured (24h/72h/7d) | Configuráveis no banco; referência `US$ 4,99 / 11,99 / 24,99` |
| **OQ-18** | Nome definitivo e domínio | Placeholders `TesterLoop` / `io.testerloop` / `testerloop.io` |
| **TQ-1..10** | Escolhas técnicas secundárias | Defaults do `SPEC.md §15` |
