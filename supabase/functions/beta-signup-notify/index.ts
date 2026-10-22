// Mails support@booksquad.de about a new beta sign-up and confirms it to the reader
// (called by a DB trigger with {id}).
// Each row is mailed at most once: notified_at is claimed before sending, released on failure.
import { createClient } from 'npm:@supabase/supabase-js@2';
import { SMTPClient } from 'https://deno.land/x/denomailer@1.6.0/mod.ts';

const MAILBOX = 'support@booksquad.de';
const PLATFORM = { ios: 'iPhone', android: 'Android' } as Record<string, string>;

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
  const { id } = await req.json().catch(() => ({}));
  if (typeof id !== 'string') return new Response('Bad request', { status: 400 });

  const password = Deno.env.get('SMTP_PASSWORD');
  if (!password) {
    console.error('beta-signup-notify: SMTP_PASSWORD secret missing');
    return new Response('Not configured', { status: 500 });
  }

  const admin = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: row, error } = await admin
    .from('beta_signups')
    .update({ notified_at: new Date().toISOString() })
    .eq('id', id)
    .is('notified_at', null)
    .select('first_name, email, platform, created_at')
    .maybeSingle();
  if (error) {
    console.error('beta-signup-notify: claim failed', error);
    return new Response('Error', { status: 500 });
  }
  if (!row) return new Response('Nothing to do');

  const { count } = await admin
    .from('beta_signups')
    .select('id', { count: 'exact', head: true });

  const client = new SMTPClient({
    connection: {
      hostname: 'smtp.ionos.de',
      port: 465,
      tls: true,
      auth: { username: MAILBOX, password },
    },
  });
  try {
    await client.send({
      from: `Booksquad <${MAILBOX}>`,
      to: MAILBOX,
      replyTo: row.email,
      subject: `Neue Beta-Anmeldung: ${row.first_name ?? row.email} (${count ?? '?'} gesamt)`,
      content: [
        'Neue Anmeldung über booksquad.de',
        '',
        `Name:   ${row.first_name ?? '–'}`,
        `E-Mail: ${row.email}`,
        `Gerät:  ${PLATFORM[row.platform] ?? row.platform}`,
        `Zeit:   ${new Date(row.created_at).toLocaleString('de-DE', { timeZone: 'Europe/Berlin' })}`,
        '',
        `Anmeldungen insgesamt: ${count ?? '?'}`,
        'Liste: Supabase → Table Editor → beta_signups → Export CSV',
      ].join('\n'),
    });
    // Confirmation to the reader. One per address (unique email), so it can't be used to spam.
    try {
      await client.send({
        from: `Booksquad <${MAILBOX}>`,
        to: row.email,
        subject: 'Du bist dabei: Booksquad-Beta 📚',
        content: [
          `Hallo${row.first_name ? ` ${row.first_name}` : ''},`,
          '',
          'danke für deine Anmeldung zur Beta von Booksquad, der App zum Lesen mit Freunden.',
          '',
          `Sobald die Beta startet, bekommst du eine Einladung über ${row.platform === 'ios' ? 'TestFlight (Apple)' : 'Google Play'} an diese Adresse. Das wird voraussichtlich im November sein.`,
          '',
          'Du hast dich nicht angemeldet oder möchtest doch nicht mitmachen? Antworte einfach auf diese Mail, dann löschen wir deine Angaben.',
          '',
          'Viele Grüße',
          'Marcello von Booksquad',
          '',
          '—',
          'Booksquad · booksquad.de · Impressum: https://booksquad.de/imprint.html · Datenschutz: https://booksquad.de/privacy.html#beta',
        ].join('\n'),
      });
    } catch (e) {
      // The owner already got the notice; a bounced confirmation is not worth a retry.
      console.error('beta-signup-notify: confirmation failed', e);
    }
  } catch (e) {
    console.error('beta-signup-notify: send failed', e);
    await admin.from('beta_signups').update({ notified_at: null }).eq('id', id);
    return new Response('Send failed', { status: 502 });
  } finally {
    try {
      await client.close();
    } catch {
      // Already closed after a failed login.
    }
  }
  return new Response('Sent');
});
