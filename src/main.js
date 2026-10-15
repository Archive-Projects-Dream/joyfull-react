import './style.scss';

import { mountOrbitalScene } from './js/components/orbital-scene.js';
import { mountShipTraffic } from './js/components/ship-traffic.js';
import { initWarp } from './js/warp.js';
import { initTheme } from './js/theme.js';
import { initUI } from './js/ui.js';

document.addEventListener('DOMContentLoaded', () => {
  const warp = initWarp();

  mountOrbitalScene(document.getElementById('orbital-planes'));
  mountShipTraffic(document.getElementById('ship-traffic'));
  initTheme(warp.redraw);
  initUI();
});
