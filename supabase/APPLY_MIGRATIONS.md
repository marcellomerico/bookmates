# Supabase — Migrationen anwenden

> **Ausführliche Test-Anleitung inkl. Verifikation:** [`TESTING.md`](../TESTING.md) (Teil A + B)

## Reihenfolge

Supabase Dashboard → **SQL** → **New query**

| # | Datei | Inhalt |
|---|-------|--------|
| 1 | `20260707180000_initial_schema.sql` | Tabellen, Genres, RLS, Auth-Trigger |
| 2 | `20260731120000_storage_and_policies.sql` | Storage `avatars` + `post-images`, Delete-Policies |
| 3 | `20260731140000_moderation_and_privacy.sql` | `blocks`, `reports`, private Groups, `delete_own_account` |
| 4 | `20260731150000_fix_account_deletion.sql` | **Account-Löschung reparieren** (Storage + robustere Funktion) |

Jeweils **gesamten Dateiinhalt** kopieren → **Run**.

> **Migration 4 ist Pflicht**, wenn du Accounts löschen und dieselbe E-Mail erneut nutzen willst.

## Schnell-Check nach Migration 4

```sql
-- 13 Tabellen?
select count(*) from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles','genres','user_genres','books','user_books',
    'groups','group_members','posts','follows','likes','comments',
    'blocks','reports'
  );
-- Erwartung: 13

-- Storage?
select id from storage.buckets where id in ('avatars','post-images');
-- Erwartung: 2 Zeilen

-- Account löschen (aktualisierte Version)?
select pg_get_functiondef(p.oid)
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'delete_own_account';
-- Erwartung: enthält "storage.objects" und "auth.users"
```

## App

Terminal: **`R`** (Hot Restart) → dann [`TESTING.md`](../TESTING.md) Teil C ff.
