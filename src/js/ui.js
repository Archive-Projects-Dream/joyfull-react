export function initUI() {
  const toggle = document.getElementById('scan-toggle');
  const crt = document.getElementById('crt');

  if (toggle && crt) {
    toggle.addEventListener('click', () => {
      const enabled = toggle.getAttribute('aria-pressed') !== 'true';
      toggle.setAttribute('aria-pressed', String(enabled));
      crt.classList.toggle('off', !enabled);
      toggle.textContent = 'SCANLINES ' + (enabled ? 'ON' : 'OFF');
    });
  }

  document.querySelectorAll('[data-placeholder]').forEach(a => {
    a.addEventListener('click', e => e.preventDefault());
  });
}