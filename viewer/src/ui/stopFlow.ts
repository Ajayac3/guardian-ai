/// The stop-authorization flow. Ending a session is a deliberate, confirmed act
/// by the verified contact — the device itself can never end it.
export function wireStopButton(
  btn: HTMLButtonElement,
  onConfirm: () => Promise<void>,
): void {
  btn.disabled = false;
  btn.addEventListener('click', async () => {
    const ok = window.confirm(
      'End this emergency session? Only do this if the person is confirmed safe.',
    );
    if (!ok) return;
    btn.disabled = true;
    btn.textContent = 'Ending…';
    try {
      await onConfirm();
      btn.textContent = 'Session ended';
    } catch (err) {
      btn.disabled = false;
      btn.textContent = 'End emergency session';
      window.alert('Could not end the session. Please try again.');
      console.error(err);
    }
  });
}
