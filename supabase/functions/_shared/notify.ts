// Delivers a one-time verification code to a contact. Production uses Resend
// (email) or Twilio (SMS) when their env vars are set; otherwise it logs the
// code so the flow works on the local stack. Set OTP_DEV_ECHO=true to also
// return the code in the API response for local testing (never in production).
export async function deliverOtp(opts: {
  channel: 'email' | 'sms';
  to: string;
  code: string;
  contactName?: string;
}): Promise<boolean> {
  const { channel, to, code } = opts;
  const who = opts.contactName ?? 'Someone';
  const body =
    `Guardian AI: ${who} added you as an emergency contact. ` +
    `Your verification code is ${code}. It expires in 10 minutes.`;

  if (channel === 'email') {
    const key = Deno.env.get('RESEND_API_KEY');
    const from =
      Deno.env.get('OTP_EMAIL_FROM') ?? 'Guardian AI <noreply@guardian.app>';
    if (key) {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${key}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          from,
          to,
          subject: 'Verify your Guardian AI emergency contact',
          text: body,
        }),
      });
      return res.ok;
    }
  } else {
    const sid = Deno.env.get('TWILIO_ACCOUNT_SID');
    const tok = Deno.env.get('TWILIO_AUTH_TOKEN');
    const from = Deno.env.get('TWILIO_FROM');
    if (sid && tok && from) {
      const res = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${btoa(`${sid}:${tok}`)}`,
            'content-type': 'application/x-www-form-urlencoded',
          },
          body: new URLSearchParams({ To: to, From: from, Body: body }),
        },
      );
      return res.ok;
    }
  }

  // Only echo the plaintext code to logs on the dev stack — never in production.
  if (Deno.env.get('OTP_DEV_ECHO') === 'true') {
    console.log(`[otp] no ${channel} provider configured; code for ${to} = ${code}`);
  } else {
    console.warn(`[otp] no ${channel} provider configured; delivery skipped`);
  }
  return false;
}
