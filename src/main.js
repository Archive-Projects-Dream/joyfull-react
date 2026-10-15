import { initWarp } from './js/warp.js';
import { initTheme } from './js/theme.js';
import { initUI } from './js/ui.js';

document.addEventListener('DOMContentLoaded', () => {
  const warp = initWarp();
  initTheme(warp.redraw);
  initUI();
});