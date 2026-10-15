export function initCameraControls() {
  const core = document.querySelector('.cosmic-core');
  if (!core) return;

  const rig = document.createElement('div');
  rig.className = 'camera-rig';

  // Rotate the orbital scene as a single rig, preserving individual orbit planes.
  while (core.firstChild) rig.append(core.firstChild);
  core.append(rig);

  let dragging = false;
  let pointerId = null;
  let lastX = 0;
  let lastY = 0;
  let yaw = 0;
  let pitch = 0;

  const applyRotation = () => {
    rig.style.setProperty('--camera-yaw', yaw + 'deg');
    rig.style.setProperty('--camera-pitch', pitch + 'deg');
  };

  rig.setAttribute(
    'aria-label',
    'Орбитальная сцена: перетащите мышью или одним пальцем, чтобы вращать камеру'
  );

  rig.addEventListener('pointerdown', (event) => {
    if (event.pointerType === 'mouse' && event.button !== 0) return;

    dragging = true;
    pointerId = event.pointerId;
    lastX = event.clientX;
    lastY = event.clientY;
    rig.classList.add('is-dragging');
    rig.setPointerCapture(pointerId);
  });

  rig.addEventListener('pointermove', (event) => {
    if (!dragging || event.pointerId !== pointerId) return;

    yaw += (event.clientX - lastX) * 0.45;
    pitch = Math.max(-55, Math.min(55, pitch - (event.clientY - lastY) * 0.4));
    lastX = event.clientX;
    lastY = event.clientY;
    applyRotation();
  });

  const stopDragging = (event) => {
    if (event.pointerId !== pointerId) return;

    dragging = false;
    rig.classList.remove('is-dragging');
    if (rig.hasPointerCapture(pointerId)) rig.releasePointerCapture(pointerId);
    pointerId = null;
  };

  rig.addEventListener('pointerup', stopDragging);
  rig.addEventListener('pointercancel', stopDragging);
  applyRotation();
}
