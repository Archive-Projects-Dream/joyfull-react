const SHIPS = ['a', 'b', 'c'];

export function mountShipTraffic(container) {
  if (!container) return;

  const fragment = document.createDocumentFragment();
  SHIPS.forEach((id) => {
    const ship = document.createElement('span');
    ship.className = `ship ship--${id}`;
    ship.setAttribute('aria-hidden', 'true');
    fragment.append(ship);
  });

  container.replaceChildren(fragment);
}
