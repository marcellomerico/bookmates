-- Follow-ups to migration 7 (phase-2 review):
-- 1. admin_open_reports returns the post image URL so the app can remove it on admin delete.
-- 2. Admins may delete objects in post-images (images of deleted posts must not stay public).
-- 3. A comment report must carry its post_id, so the visibility check cannot be skipped.

drop function if exists public.admin_open_reports();
create function public.admin_open_reports()
returns table (
  report_id uuid, reported_at timestamptz, reason text, reporter_username text,
  target_user_id uuid, target_username text, target_post_id uuid, target_comment_id uuid,
  content text, content_hidden boolean, target_image_url text
)
language sql stable security definer set search_path = public as $$
  select r.id, r.created_at, r.reason, rp.username,
         coalesce(r.reported_user_id, c.author_id, p.author_id), tu.username,
         r.post_id, r.comment_id,
         case when r.target_type = 'comment' then c.content else p.content end,
         case when r.target_type = 'comment' then c.hidden_at else p.hidden_at end is not null,
         case when r.target_type = 'post' then p.image_url end
  from public.reports r
  left join public.profiles rp on rp.id = r.reporter_id
  left join public.comments c on c.id = r.comment_id
  left join public.posts p on p.id = r.post_id
  left join public.profiles tu on tu.id = coalesce(r.reported_user_id, c.author_id, p.author_id)
  where private.is_admin() and r.status = 'open'
  order by r.created_at;
$$;
revoke all on function public.admin_open_reports() from public, anon;
grant execute on function public.admin_open_reports() to authenticated;

drop policy if exists "Admins delete post images" on storage.objects;
create policy "Admins delete post images" on storage.objects
  for delete to authenticated
  using (bucket_id = 'post-images' and private.is_admin());

drop policy if exists "Users create reports" on public.reports;
create policy "Users create reports" on public.reports for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and (reports.comment_id is null or reports.post_id is not null)
    and (reports.post_id is null or private.can_view_post(reports.post_id))
    and (reports.comment_id is null or exists (
          select 1 from public.comments c
          where c.id = reports.comment_id
            and c.post_id = reports.post_id))
  );
