// Éditeur de parcours sur une carte OpenStreetMap (Leaflet).
// Clic : ajoute un point. Glisser un point : le déplace. La zone de présence
// est prévisualisée par un trait dont l'épaisseur suit la largeur en mètres.
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { LineString } from './api';

const FRANCE: L.LatLngExpression = [46.6, 2.4];

export interface RouteEditor {
  getRoute(): LineString | null;
  setBuffer(meters: number): void;
  setColors(primary: string, deep: string): void;
  undo(): void;
  clear(): void;
  lengthMeters(): number;
  centerOn(lat: number, lng: number): void;
  destroy(): void;
}

export function createRouteEditor(
  container: HTMLElement,
  initial: LineString | null,
  bufferM: number,
  colors: { primary: string; deep: string },
  onChange: () => void,
  readonly = false,
): RouteEditor {
  const map = L.map(container, { zoomControl: true, attributionControl: true });
  L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
    maxZoom: 19,
    attribution: '© contributeurs <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(map);

  let points: L.LatLng[] = (initial?.coordinates ?? []).map(([lng, lat]) => L.latLng(lat, lng));
  let buffer = bufferM;
  let c = colors;

  const zone = L.polyline([], { opacity: 0.22, lineCap: 'round', lineJoin: 'round', interactive: false }).addTo(map);
  const casing = L.polyline([], { color: '#FFFFFF', weight: 8, lineCap: 'round', lineJoin: 'round', interactive: false }).addTo(map);
  const line = L.polyline([], { weight: 5, lineCap: 'round', lineJoin: 'round', interactive: false }).addTo(map);
  const markers = L.layerGroup().addTo(map);

  function metersPerPixel(): number {
    const lat = map.getCenter().lat;
    return (40075016.686 * Math.cos((lat * Math.PI) / 180)) / Math.pow(2, map.getZoom() + 8);
  }

  function vertexIcon(kind: 'start' | 'end' | 'mid'): L.DivIcon {
    const size = kind === 'mid' ? 14 : 20;
    const fill = kind === 'end' ? 'var(--pop, #FFC531)' : '#FFFFFF';
    return L.divIcon({
      className: 'route-vertex',
      iconSize: [size, size],
      html: `<span style="display:block;width:${size}px;height:${size}px;border-radius:50%;background:${fill};border:3px solid ${c.deep};box-sizing:border-box"></span>`,
    });
  }

  function redraw(): void {
    zone.setLatLngs(points);
    casing.setLatLngs(points);
    line.setLatLngs(points);
    zone.setStyle({ color: c.primary, weight: Math.max(4, (2 * buffer) / metersPerPixel()) });
    line.setStyle({ color: c.primary });
    markers.clearLayers();
    points.forEach((p, i) => {
      const kind = i === 0 ? 'start' : i === points.length - 1 && points.length > 1 ? 'end' : 'mid';
      const m = L.marker(p, {
        icon: vertexIcon(kind),
        draggable: !readonly,
        keyboard: false,
        title: kind === 'start' ? 'Départ' : kind === 'end' ? 'Arrivée' : `Point ${i + 1}`,
      });
      m.on('drag', () => {
        points[i] = m.getLatLng();
        zone.setLatLngs(points);
        casing.setLatLngs(points);
        line.setLatLngs(points);
      });
      m.on('dragend', () => {
        points[i] = m.getLatLng();
        redraw();
        onChange();
      });
      markers.addLayer(m);
    });
  }

  if (!readonly) {
    map.on('click', (e: L.LeafletMouseEvent) => {
      points.push(e.latlng);
      redraw();
      onChange();
    });
  }
  map.on('zoomend', redraw);

  if (points.length >= 2) {
    map.fitBounds(L.latLngBounds(points), { padding: [40, 40] });
  } else {
    map.setView(FRANCE, 6);
  }
  redraw();
  // La carte est souvent créée avant que son conteneur ait sa taille finale
  setTimeout(() => map.invalidateSize(), 0);

  return {
    getRoute() {
      if (points.length < 2) return null;
      return {
        type: 'LineString',
        coordinates: points.map((p) => [round(p.lng), round(p.lat)] as [number, number]),
      };
    },
    setBuffer(m) {
      buffer = m;
      redraw();
    },
    setColors(primary, deep) {
      c = { primary, deep };
      redraw();
    },
    undo() {
      points.pop();
      redraw();
      onChange();
    },
    clear() {
      points = [];
      redraw();
      onChange();
    },
    lengthMeters() {
      let total = 0;
      for (let i = 1; i < points.length; i++) total += map.distance(points[i - 1], points[i]);
      return total;
    },
    centerOn(lat, lng) {
      map.setView([lat, lng], 15);
    },
    destroy() {
      map.remove();
    },
  };
}

// 6 décimales ≈ 10 cm : largement assez, et des requêtes plus légères
function round(x: number): number {
  return Math.round(x * 1e6) / 1e6;
}
