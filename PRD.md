# PRD — TesterLoop (nome provisório)

> **Status:** Rascunho v0.1 · **Data:** 2026-11-12 · **Autor:** Luís Ribeiro
> Documento de produto. Detalhes técnicos estão em [`SPEC.md`](./SPEC.md).
> Itens marcados com **❓ OQ-n** são pontos em aberto e estão consolidados na seção 12.

---

## 1. Contexto e problema

Contas de desenvolvedor **pessoais** do Google Play criadas após 13/11/2023 só conseguem pedir acesso à produção depois de rodar um **teste fechado com pelo menos 12 testadores que estejam inscritos (opt-in) de forma contínua nos últimos 14 dias**. O número de testadores caiu de 20 para 12 no fim de 2024. O prazo continua sendo de 14 dias.

> ⚠️ **❓ OQ-1 — 7 dias ou 14 dias?** O pedido original fala em "7 dias", mas a regra atual do Google é **14 dias contínuos**. Este PRD usa **14 dias por padrão** e deixa a duração **configurável no servidor**, para acompanhar mudanças de política sem lançar uma nova versão do app.

Na prática, devs independentes enfrentam:

- **Dificuldade para achar 12 pessoas** com Android que topem instalar o app e manter a inscrição por 14 dias.
- **Abandono:** um testador que sai da lista no dia 10 zera a contagem dele, e o dev só percebe tarde.
- **Falta de prova de engajamento:** no pedido de acesso à produção, o Google pergunta como foi o teste (engajamento e feedback recebido). As comunidades informais (grupos de Telegram/Reddit, planilhas de "troca de testes") não registram nada disso.
- **Falta de confiança:** em trocas informais, ninguém sabe se o outro lado realmente instalou e abriu o app.

## 2. Visão do produto

Um **marketplace de troca de testes com verificação real**: o dev ganha **pontos** testando apps de outras pessoas e usa esses pontos para cadastrar o próprio app e receber testadores. Um **SDK leve (Kotlin + plugin Flutter)** embutido no app testado comprova a instalação e o uso, e é ele que libera os pontos.

**Proposta de valor em uma frase:** *"Consiga seus 12 testadores por 14 dias com prova de uso e feedback real, testando apps de outros devs."*

## 3. Objetivos e não-objetivos

### Objetivos (MVP)
1. Permitir que um dev **cadastre o app e complete o teste fechado** em ~14–20 dias.
2. **Verificar automaticamente** a instalação e o uso diário por meio do SDK, sem confiar na palavra do testador.
3. Ter uma **economia de pontos** que se sustente sozinha (quem precisa de testadores também testa).
4. Gerar **feedback estruturado** que o dev possa usar no formulário de acesso à produção.
5. Ter uma **landing page em Astro** otimizada para SEO/AEO como principal canal de aquisição orgânica.
6. Monetizar com **3 slots "Featured"** pagos.

### Não-objetivos (MVP)
- Suporte a iOS/TestFlight (o requisito é só do Google Play).
- Automatizar ações no Play Console (adicionar testadores por API, por exemplo).
- Testes de QA profissionais/pagos por testador. Pode virar um produto separado no futuro.
- Garantir aprovação do Google para produção. **Não podemos prometer isso**, e a comunicação precisa deixar isso claro.

## 4. Personas

| Persona | Descrição | Necessidade principal |
|---|---|---|
| **Dev Indie (principal)** | Conta pessoal nova, primeiro app, sem rede de contatos para testes. | Fechar 12×14 rápido e sem dor de cabeça. |
| **Dev recorrente** | Já publicou e lança apps novos com frequência (cada app novo de conta pessoal nova passa pelo processo). | Previsibilidade e destaque (Featured). |
| **Testador "farmer"** | Dev que acumula pontos para usar depois ou para trocar com amigos. | Muitos apps disponíveis e lembretes. |
| **Agência/Estúdio** | Publica apps de clientes em contas pessoais. | Gerenciar vários apps. Possível plano pago (❓ OQ-14). |

## 5. Escopo funcional

### 5.1 App Hub (Flutter, Android)
O app principal é usado tanto por testadores quanto por devs.

| # | Funcionalidade | Prioridade |
|---|---|---|
| H1 | Cadastro/login (Google Sign-In obrigatório, já que testes fechados dependem da conta Google). | P0 |
| H2 | **Descobrir apps:** abas **Featured (3)**, **Recentes** e **Mais testadores / quase completos**. | P0 |
| H3 | Detalhe do app: descrição, screenshots, vagas ocupadas `x/12`, dias restantes, pontos oferecidos, botão **"Quero testar"**. | P0 |
| H4 | Fluxo de inscrição guiado: entrar no grupo/lista → abrir o link de opt-in do Play → instalar → abrir pelo Hub (handshake do SDK). | P0 |
| H5 | **Meus testes:** progresso dia a dia por app (✓ dia validado, ⚠ pendente hoje, ✗ perdido). | P0 |
| H6 | **Lembretes diários** (push) para abrir os apps em teste que ainda não foram usados no dia. | P0 |
| H7 | **Carteira de pontos:** saldo disponível, pontos pendentes (em custódia) e extrato. | P0 |
| H8 | **Meus apps (dev):** cadastrar app, obter `appKey`, **validar o SDK** ("teste de launch"), publicar campanha, acompanhar testadores. | P0 |
| H9 | Feedback do testador: formulário curto (nota, bugs, sugestão) com bônus de pontos por feedback de qualidade. | P1 |
| H10 | **Relatório de campanha** exportável (PDF/Markdown) com engajamento e feedbacks, para usar no pedido de produção. | P1 |
| H11 | Comprar slot **Featured** (Google Play Billing). | P1 |
| H12 | Reputação do testador (taxa de conclusão), usada para priorizar e evitar abuso. | P1 |
| H13 | Exclusão de conta dentro do app e pela web (exigência do Play e da LGPD). | P0 |

> **❓ OQ-2 — Console web para devs?** Cadastrar o app e ver relatórios fica mais confortável no desktop. Sugestão: o mesmo código Flutter compilado para **Flutter Web** (`console.<domínio>`) a partir da fase 2. No MVP, tudo fica no app Android.

### 5.2 SDK de rastreamento
| # | Requisito | Prioridade |
|---|---|---|
| S1 | **Kotlin/Android:** instalação = 1 dependência + 1 `meta-data` no Manifest. Zero código obrigatório (auto-init). | P0 |
| S2 | **Plugin Flutter:** `flutter pub add testerloop` + a mesma `meta-data`. Zero código Dart obrigatório. | P0 |
| S3 | Registrar instalação (origem Play Store), sessões em foreground e dias ativos. | P0 |
| S4 | Associar o uso ao testador do Hub **sem coletar e-mail nem dados pessoais** no app testado. | P0 |
| S5 | Leve: < 50 KB, sem dependências pesadas e sem impacto mensurável no startup. | P0 |
| S6 | **Kill-switch:** vira no-op quando a campanha termina ou no build de produção (configurável). | P0 |
| S7 | Documentação **"AI-ready"** (`AI_INSTALL.md` + `llms.txt`), com passos determinísticos que qualquer IA consiga aplicar. | P0 |
| S8 | Texto pronto para o **formulário Data Safety** do Play. | P0 |

### 5.3 Landing page (Astro)
| # | Requisito | Prioridade |
|---|---|---|
| L1 | Home com proposta de valor, como funciona, CTA para o Play Store. | P0 |
| L2 | Páginas de conteúdo voltadas para busca: "Como conseguir 12 testadores", "Requisito de 14 dias do Google Play explicado", "Teste fechado passo a passo". | P0 |
| L3 | Docs do SDK (Kotlin e Flutter) com `llms.txt` e `llms-full.txt`. | P0 |
| L4 | FAQ com `FAQPage` JSON-LD, mais `SoftwareApplication` e `Organization`. | P0 |
| L5 | i18n **pt-BR + en** (o mercado em inglês é muito maior). ❓ OQ-12 | P0 |
| L6 | Diretório público de apps em teste (páginas indexáveis por app, opt-in do dev). ❓ OQ-13 | P2 |
| L7 | Lighthouse ≥ 95 em todas as categorias e Core Web Vitals no verde. | P0 |

### 5.4 Featured (monetização)
- **3 slots** fixos no topo do Hub (e, opcionalmente, na landing).
- Duração em blocos de tempo (ex.: 24h, 72h, 7 dias).
- Só campanhas **ativas e com SDK validado** podem ser destacadas.
- Modelo de preço: **❓ OQ-8 (fixo × leilão)**. A recomendação está na seção 8.

## 6. Jornadas principais

### 6.1 Testador ganha pontos
1. Abre o Hub → aba **Recentes** → escolhe um app → **"Quero testar"**.
2. O Hub mostra os passos: (a) entrar no grupo de testers, (b) aceitar o convite pelo link de opt-in, (c) instalar pela Play Store.
3. Toca em **"Abrir e validar"** → o Hub abre o app testado → o SDK faz o handshake → status **Inscrito ✓**.
4. Todo dia, ao abrir o app testado por ≥ 60s, o dia conta como **validado** (+1 ponto pendente).
5. No dia 14 contínuo, os pontos pendentes viram **disponíveis**, com bônus de conclusão.
6. (Opcional) Envia feedback e ganha bônus.

### 6.2 Dev cadastra o app
1. **Meus apps → Novo app:** nome, package name, ícone, descrição, link de opt-in do teste fechado.
2. Recebe um `appKey` e as instruções (ou um prompt pronto para colar na IA) para instalar o SDK.
3. Sobe o build com SDK no **track de teste fechado** e adiciona o grupo de testers da plataforma (❓ OQ-4).
4. **Teste de launch:** no Hub, toca em **"Validar SDK"** → instala o próprio app pelo Play → abre pelo Hub → o backend confirma package, assinatura e origem Play → **SDK verificado ✓**.
5. **Publicar campanha** (consome X pontos) → o app entra em "Recentes".
6. Acompanha o painel: testadores `x/12`, dias contínuos de cada um, previsão de conclusão e feedbacks.
7. Quando houver ≥ 12 testadores com 14 dias, **campanha concluída** → relatório exportável → pede acesso à produção no Play Console.

## 7. Economia de pontos (proposta inicial)

**Princípio:** cada campanha consome **12 testadores × 14 dias = 168 testador-dias**. Para a economia se equilibrar, o custo de publicar precisa ficar próximo do que o dev "devolve" à comunidade.

| Regra | Valor inicial sugerido (configurável) |
|---|---|
| Ponto por dia validado por app | **1** (pendente até concluir) |
| Bônus de conclusão (14 dias contínuos) | **+3** por app |
| Bônus por feedback aprovado | **+2** (máx. 1 por app) |
| Custo para publicar campanha (12 vagas) | **120 pontos** |
| Bônus de boas-vindas | **10 pontos** |
| Limite de testes simultâneos por testador | **20** |
| Abandono antes de concluir | Perde os pontos pendentes daquele app e a reputação cai |

Na prática, quem testa **~7 apps em paralelo por 14 dias** (7 × 17 = 119 pontos) consegue publicar um app. Como o custo (120) fica abaixo de 168, a plataforma "subsidia" ~29% do esforço, e isso é compensado por usuários que só testam ou que testam mais do que publicam. Os valores devem ser ajustados com dados reais (tempo médio de preenchimento das vagas).

> **❓ OQ-5** Pontos pendentes por dia ou só na conclusão? (Recomendado: acumular diariamente como *pendente* e liberar na conclusão, o que protege o dev contra abandono.)
> **❓ OQ-6** Pontos podem ser **comprados**? (Recomendação: **não** no MVP. Vender pontos quebra a reciprocidade e transforma o produto em "venda de testadores", o que aumenta o risco de política do Google. Monetizar só com Featured.)
> **❓ OQ-7** Pontos expiram? (Sugestão: expiram após 180 dias sem atividade.)

## 8. Featured: recomendação

| Critério | Preço fixo | Leilão |
|---|---|---|
| Complexidade | Baixa | Alta (lances, desempate, reembolso) |
| Compatível com Google Play Billing | **Sim** (produto consumível com preço fixo) | Difícil: o IAP tem preços fixos, então exigiria uma carteira de créditos |
| Receita com pouca demanda | Previsível | Baixa (lances mínimos) |
| Receita com muita demanda | Deixa dinheiro na mesa | Maximiza |

**Recomendação:** **MVP com preço fixo + fila/agenda** (o usuário reserva o próximo bloco livre de 24h/72h/7d). Na **fase 3**, migrar para um **leilão de segundo preço selado por dia**, usando **créditos pagos** (moeda separada dos pontos), quando houver demanda maior que a oferta (ocupação > 80% por 4 semanas).

> **❓ OQ-8** Fixo ou leilão no lançamento? **❓ OQ-9** Preços iniciais (sugestão: US$ 4,99/24h · US$ 11,99/72h · US$ 24,99/7d, com preço regional no Play). **❓ OQ-10** Campanha Featured ainda paga pontos para publicar? (Sugestão: sim. Featured só dá visibilidade.) **❓ OQ-11** Vender Featured também pela web (Stripe)? Isso exige atenção às regras de cobrança do Play.

## 9. Métricas de sucesso

| Métrica | Meta (6 meses após o lançamento) |
|---|---|
| **Tempo até preencher 12 vagas** (mediana) | ≤ 72h |
| **Taxa de conclusão de campanha** (≥ 12 testadores × 14 dias) | ≥ 80% |
| Taxa de abandono de testadores antes do dia 14 | ≤ 15% |
| Instalação do SDK → validação com sucesso | ≥ 90% na primeira tentativa |
| Ocupação dos slots Featured | ≥ 60% |
| Tráfego orgânico da landing | 10k visitas/mês |
| Instalações vindas da landing | ≥ 25% do total |

## 10. Riscos

| Risco | Impacto | Mitigação |
|---|---|---|
| **Política do Google Play:** o Google pode ver a troca de testes como manipulação, ou ver o Hub como app de "instalações incentivadas". | Alto: remoção do Hub ou rejeição de produção para os devs | Posicionar o produto como **teste real com feedback**; exigir uso diário real; não vender pontos; incentivar feedback; consultar a política antes do lançamento; ter **plano B de distribuição** (APK pela landing). |
| **O próprio Hub precisa de 12 testadores.** | Médio | Publicar com **conta de organização** (CNPJ/D-U-N-S), que é isenta do requisito. ❓ OQ-15 |
| **Fraude:** emuladores, várias contas no mesmo aparelho, scripts que abrem apps. | Alto | Play Integrity no Hub, 1 conta por dispositivo, sessão mínima em foreground, heurísticas e reputação. |
| **Cold start:** sem testadores, ninguém completa campanhas. | Alto | Lista de espera, bônus para os primeiros usuários, seeding em comunidades de devs, campanhas "founder" com 0 pontos. |
| O testador sai do grupo/opt-in sem desinstalar (não detectável pelo SDK). | Médio | Exigir uso diário, que funciona como proxy. Avisar o dev sobre a discrepância com o Play Console. |
| SDK esquecido em produção. | Baixo | Kill-switch remoto e no-op automático após a conclusão. Docs recomendam a remoção. |
| LGPD / Data Safety. | Médio | Minimizar dados (sem PII no SDK), política de privacidade, DPA para devs. |

## 11. Roadmap

| Fase | Duração estimada | Entregas |
|---|---|---|
| **0 — Fundação** | 2 semanas | Backend, auth, modelo de dados, SDK Kotlin v0 (handshake + heartbeat), landing com lista de espera. |
| **1 — MVP fechado** | 4–6 semanas | Hub Android (H1–H8, H13), plugin Flutter, validação do SDK, economia de pontos, push. Beta com 50–100 devs. |
| **2 — Lançamento público** | 3–4 semanas | Feedback (H9), relatório (H10), Featured com preço fixo (H11), reputação, landing completa com SEO/AEO e docs, console Flutter Web. |
| **3 — Escala** | contínuo | Leilão de Featured, diretório público, planos para agências, analytics para devs. |

## 12. Pontos em aberto (consolidado)

| ID | Pergunta | Recomendação |
|---|---|---|
| **OQ-1** | Duração: 7 ou 14 dias? | **14** (regra atual do Google), configurável. |
| **OQ-2** | Console web para devs no MVP? | Fase 2, em Flutter Web. |
| **OQ-3** | "Máx. 12 ao mesmo tempo" é o limite de **testadores por campanha** ou o **tamanho da lista** "mais usuários"? | Entendido como **vagas por campanha**. Sugestão: **12 + 3 de reserva** (15), porque qualquer abandono atrasa a conclusão em 14 dias. |
| **OQ-4** | Como o testador entra na lista do Play: **Google Group global da plataforma** ou **e-mails individuais** enviados ao dev? | **Google Group(s) da plataforma**: o dev adiciona o grupo uma vez, e o testador entra no grupo com a conta do Play. Evita trocar e-mails (LGPD). |
| **OQ-5** | Pontos diários ou só na conclusão? | Diários como *pendentes*, liberados na conclusão. |
| **OQ-6** | Venda de pontos? | Não no MVP. |
| **OQ-7** | Pontos expiram? | 180 dias sem atividade. |
| **OQ-8** | Featured: fixo ou leilão? | Fixo no MVP, leilão na fase 3. |
| **OQ-9** | Preço do Featured? | Ver seção 8. |
| **OQ-10** | Featured isenta o custo em pontos? | Não. |
| **OQ-11** | Vender Featured pela web? | Avaliar depois, com cuidado com a política de pagamentos do Play. |
| **OQ-12** | Idiomas no lançamento? | pt-BR + en. |
| **OQ-13** | Diretório público de apps na landing (SEO programático)? | Sim, na fase 3, com opt-in do dev. |
| **OQ-14** | Plano pago para agências (vários apps, sem gastar pontos)? | Avaliar depois de validar a economia. |
| **OQ-15** | O Hub vai ser publicado em conta pessoal ou de organização? | Organização. |
| **OQ-16** | O que conta como "dia testado": só ter o app instalado, ou abrir e usar ≥ N segundos? | **Abrir ≥ 60s em foreground** no dia (fuso do testador). |
| **OQ-17** | Backend: Supabase × Firebase × próprio? | **Supabase** (Postgres para ledger/rankings, ver SPEC §3). |
| **OQ-18** | Nome definitivo e domínio do produto? | — |
| **OQ-19** | O app do testador precisa de um uso mínimo ou de uma "tarefa" (ex.: completar onboarding) definida pelo dev? | Fase 3, como "missões" opcionais com bônus. |
