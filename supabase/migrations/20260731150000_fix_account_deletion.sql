-- Fix: complete account deletion including storage; safe re-registration

create or replace function public.delete_own_account()
returns void
language plpgsql
security definer
set search_path = public, auth, storage
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Remove uploaded files (avatars, post images)
  delete from storage.objects
  where bucket_id in ('avatars', 'post-images')
    and (storage.foldername(name))[1] = uid::text;

  -- Cascades: profiles, posts, follows, etc.
  delete from auth.users where id = uid;

  if not found then
    raise exception 'Account could not be deleted';
  end if;
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;

-- Allow checking username availability before sign-up (public read already exists on profiles)
