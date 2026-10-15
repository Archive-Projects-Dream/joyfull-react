export function initWarp() {
  const canvas = document.getElementById('warp');
  const ctx = canvas.getContext('2d', { alpha: false });
  let width = 0, height = 0, cx = 0, cy = 0, raf = 0;
  const stars = [];
  const STAR_COUNT = 260;
  const MAX_DEPTH = 1500;
  let reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function resize() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    width = window.innerWidth;
    height = window.innerHeight;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    cx = width / 2;
    cy = height / 2;
  }

  class Star {
    constructor() { this.reset(true); }
    reset(initial = false) {
      this.x = (Math.random() - 0.5) * width * 3.5;
      this.y = (Math.random() - 0.5) * height * 3.5;
      this.z = initial ? Math.random() * MAX_DEPTH : MAX_DEPTH;
      this.pz = this.z;
    }
    update() {
      if (reduceMotion) return;
      this.pz = this.z;
      this.z -= 5.5;
      if (this.z < 2) this.reset();
    }
    draw() {
      const x = (this.x / this.z) * cx + cx;
      const y = (this.y / this.z) * cy + cy;
      const px = (this.x / this.pz) * cx + cx;
      const py = (this.y / this.pz) * cy + cy;
      const brightness = 1 - this.z / MAX_DEPTH;

      const rootStyles = getComputedStyle(document.documentElement);
      const r = Number(rootStyles.getPropertyValue('--star-r').trim()) || 220;
      const g = Number(rootStyles.getPropertyValue('--star-g').trim()) || 220;
      const b = Number(rootStyles.getPropertyValue('--star-b').trim()) || 220;

      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(x, y);
      ctx.strokeStyle = `rgba(${r},${g},${b},${brightness * 0.8})`;
      ctx.lineWidth = Math.max(0.4, brightness * 2);
      ctx.stroke();
    }
  }

  function init() {
    resize();
    stars.length = 0;
    for (let i = 0; i < STAR_COUNT; i++) stars.push(new Star());
    draw();
  }

  function draw() {
    const bg = getComputedStyle(document.body).getPropertyValue('--bg').trim() || '#090704';
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, width, height);
    for (const star of stars) {
      star.update();
      star.draw();
    }
    if (!reduceMotion) raf = requestAnimationFrame(draw);
  }

  window.addEventListener('resize', resize);
  init();

  // Экспортируем функцию перерисовки для смены темы
  return { redraw: draw };
}