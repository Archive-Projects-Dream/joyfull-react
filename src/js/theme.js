export function initTheme(warpRedraw) {
  const themeButtons = [...document.querySelectorAll('button[data-theme]')];
  let swapping = false;

  themeButtons.forEach((button) => {
    button.addEventListener('click', () => {
      const theme = button.dataset.theme;
      if (swapping || document.body.dataset.theme === theme) return;

      swapping = true;
      document.body.classList.add('theme-swap');

      window.setTimeout(() => {
        document.body.dataset.theme = theme;
        themeButtons.forEach((item) => {
          item.setAttribute('aria-pressed', String(item === button));
        });

        if (warpRedraw) warpRedraw();
        document.body.classList.remove('theme-swap');
        swapping = false;
      }, 200);
    });
  });
}
