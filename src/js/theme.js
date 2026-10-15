export function initTheme(warpRedraw) {
  const themeButtons = [...document.querySelectorAll('[data-theme]')];
  let swapping = false;

  themeButtons.forEach(button => {
    button.addEventListener('click', () => {
      const theme = button.dataset.theme;
      if (swapping || document.body.dataset.theme === theme) return;

      swapping = true;
      document.body.classList.add('theme-swap');

      setTimeout(() => {
        document.body.dataset.theme = theme;
        themeButtons.forEach(b => b.setAttribute('aria-pressed', String(b === button)));
        if (warpRedraw) warpRedraw(); // Перерисовываем канвас с новыми цветами
        document.body.classList.remove('theme-swap');
        swapping = false;
      }, 200);
    });
  });
}