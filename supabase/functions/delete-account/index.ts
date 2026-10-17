// Deletes the caller's storage files and auth user (Apple 5.1.1(v), GDPR Art. 17).
// Uses the Storage API: direct SQL deletes on storage.objects orphan files / are blocked.
import { createClient } from 'npm:@supabase/supabase-js@2';

const BUCKETS = ['avatars', 'post-images'];
const MAX_BATCHES = 50;

function fail(message: string, detail: unknown) {
  console.error(`delete-account: ${message}`, detail);
  return new Response('Account deletion failed', { status: 500 });
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response('Unauthorized', { status: 401 });
  const token = authHeader.replace(/^Bearer\s+/i, '');

  const url = Deno.env.get('SUPABASE_URL')!;
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
  const { data: { user }, error: userError } = await userClient.auth.getUser(token);
  if (userError || !user) return new Response('Unauthorized', { status: 401 });

  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  for (const bucket of BUCKETS) {
    // Re-list from offset 0 after each removal until the user's folder is empty.
    let previous = '';
    for (let batch = 0; batch < MAX_BATCHES; batch++) {
      const { data: files, error } = await admin.storage.from(bucket).list(user.id, { limit: 100 });
      if (error) return fail('storage list failed', error);
      if (!files || files.length === 0) break;
      const names = files.map((f) => f.name).join('/');
      if (names === previous) break; // nothing removable (placeholder/nested folder), avoid spinning
      previous = names;
      const { error: removeError } = await admin.storage
        .from(bucket)
        .remove(files.map((f) => `${user.id}/${f.name}`));
      if (removeError) return fail('storage remove failed', removeError);
    }
  }

  // Cascades to profiles, posts, comments, likes, follows, memberships, blocks, reports.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return fail('deleteUser failed', deleteError);

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
