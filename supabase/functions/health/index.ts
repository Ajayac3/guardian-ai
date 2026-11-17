// Minimal no-import function to sanity-check the edge runtime.
Deno.serve(() =>
  new Response(JSON.stringify({ ok: true }), {
    headers: { 'content-type': 'application/json' },
  })
);
