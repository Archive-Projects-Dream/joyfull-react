const ORBITS = [
  { id: 1, duration: 14, direction: 'normal', label: 'inner orbit' },
  { id: 2, duration: 22, direction: 'reverse', label: 'second orbit' },
  { id: 3, duration: 32, direction: 'normal', label: 'middle orbit' },
  { id: 4, duration: 27, direction: 'reverse', label: 'tracer-only orbit', tracerOnly: true },
  { id: 5, duration: 39, direction: 'normal', label: 'outer orbit' },
];

function createOrbit({ id, duration, direction, label, tracerOnly = false }) {
  const plane = document.createElement('div');
  plane.className = `ring-plane ring-plane-${id}${tracerOnly ? ' ring-plane-tracer-only' : ''}`;
  plane.setAttribute('aria-label', label);

  const ring = document.createElement('div');
  ring.className = `ring ring-${id}`;

  const track = document.createElement('div');
  track.className = 'orbit-track';
  track.style.setProperty('--orbit-duration', `${duration}s`);
  track.style.setProperty('--orbit-direction', direction);

  const marker = document.createElement('span');
  marker.className = 'orbit-point';

  track.append(marker);
  plane.append(ring, track);
  return plane;
}

export function mountOrbitalScene(container) {
  if (!container) return;

  const fragment = document.createDocumentFragment();
  ORBITS.forEach((orbit) => fragment.append(createOrbit(orbit)));
  container.replaceChildren(fragment);
}
