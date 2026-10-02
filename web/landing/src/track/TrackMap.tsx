import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useEffect, useRef } from 'react';

interface Point {
  latitude: number;
  longitude: number;
}

/** OpenStreetMap map with the car and the destination; keeps both in view. */
export function TrackMap({ car, destination, carLabel, destinationLabel }: {
  car: Point | null;
  destination: Point;
  carLabel: string;
  destinationLabel: string;
}) {
  const element = useRef<HTMLDivElement>(null);
  const map = useRef<L.Map | null>(null);
  const carMarker = useRef<L.CircleMarker | null>(null);

  useEffect(() => {
    if (!element.current || map.current) return;
    map.current = L.map(element.current, { zoomControl: true, attributionControl: true });
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 18,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    }).addTo(map.current);
    L.circleMarker([destination.latitude, destination.longitude], {
      radius: 8, color: '#ffffff', weight: 3, fillColor: '#161816', fillOpacity: 1,
    }).bindTooltip(destinationLabel).addTo(map.current);
    map.current.setView([destination.latitude, destination.longitude], 11);

    return () => {
      map.current?.remove();
      map.current = null;
      carMarker.current = null;
    };
  }, [destination.latitude, destination.longitude, destinationLabel]);

  useEffect(() => {
    if (!map.current || !car) return;
    const position: L.LatLngExpression = [car.latitude, car.longitude];
    if (carMarker.current) {
      carMarker.current.setLatLng(position);
    } else {
      carMarker.current = L.circleMarker(position, {
        radius: 10, color: '#ffffff', weight: 3, fillColor: '#1f7a0f', fillOpacity: 1,
      }).bindTooltip(carLabel, { permanent: true, direction: 'top', offset: [0, -10] }).addTo(map.current);
    }
    map.current.fitBounds(L.latLngBounds([position, [destination.latitude, destination.longitude]]), {
      padding: [40, 40],
      maxZoom: 14,
    });
  }, [car, carLabel, destination.latitude, destination.longitude]);

  return <div ref={element} className="track-map" role="img" aria-label={`${carLabel} → ${destinationLabel}`} />;
}
