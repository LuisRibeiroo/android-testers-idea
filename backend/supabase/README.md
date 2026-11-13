# Backend — Supabase Self-Hosted em VPS (OQ-17)

Infraestrutura escolhida para manter custo fixo previsível sem cobrança por MAU ou egress de nuvem gerenciada.

## Estrutura
- `migrations/`: Schema SQL, triggers, RLS, RPCs `security definer` e agendamentos `pg_cron` (incluindo expiração de pontos em **360 dias** — `OQ-7`).
- `functions/`: Edge Functions TypeScript/Deno (`/sdk/v1/*`, `/hub/v1/*`, `/billing/v1/*`).
- `seed.sql`: Parâmetros iniciais de `config`, produtos Featured e referência comunitária (`r/AndroidAppTesters`).
- `docker-compose.vps.yml`: Stack containerizada para deploy em VPS Linux.

## Subida em VPS
1. Copie `.env.example` para `.env` e preencha os segredos (incluindo par de chaves ES256 para `TRACKING_JWT_PRIVATE_JWK` / `TRACKING_JWT_PUBLIC_JWK`).
2. Configure um proxy reverso com TLS (ex.: Caddy) apontando `https://api.<seu-dominio>` para `127.0.0.1:8000`.
3. Suba os containers:
   ```bash
   docker compose -f docker-compose.vps.yml up -d
   ```
4. Aplique migrations e seed (ou via `supabase db push` apontando para o Postgres da VPS):
   ```bash
   psql "$DATABASE_URL" -f migrations/20261113000001_initial_schema.sql
   psql "$DATABASE_URL" -f migrations/20261113000002_rls_and_rpcs.sql
   psql "$DATABASE_URL" -f migrations/20261113000003_cron_jobs.sql
   psql "$DATABASE_URL" -f seed.sql
   ```

## Backup diário sugerido (`crontab` na VPS)
```cron
0 4 * * * docker exec $(docker ps -qf name=db) pg_dump -U postgres -Fc postgres | gzip > /var/backups/testerloop/pg_$(date +\%F).dump.gz
```
