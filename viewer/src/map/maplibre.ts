import maplibregl from 'maplibre-gl';
import type { StyleSpecification } from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

export interface LiveMap {
  setLocation(lat: number, lng: number): void;
  destroy(): void;
}

/// An OpenStreetMap raster map (no API key) with a single live marker.
export function createMap(container: HTMLElement, osmTileUrl: string): LiveMap {
  const style: StyleSpecification = {
    version: 8,
    sources: {
      osm: {
        type: 'raster',
        tiles: [osmTileUrl],
        tileSize: 256,
        attribution: '© OpenStreetMap contributors',
      },
    },
    layers: [{ id: 'osm', type: 'raster', source: 'osm' }],
  };

  const map = new maplibregl.Map({
    container,
    style,
    center: [0, 20],
    zoom: 1,
    attributionControl: { compact: true },
  });

  let marker: maplibregl.Marker | null = null;
  let centered = false;

  return {
    setLocation(lat: number, lng: number): void {
      const lngLat: [number, number] = [lng, lat];
      if (marker === null) {
        marker = new maplibregl.Marker({ color: '#d32f2f' })
          .setLngLat(lngLat)
          .addTo(map);
      } else {
        marker.setLngLat(lngLat);
      }
      if (!centered) {
        map.flyTo({ center: lngLat, zoom: 15 });
        centered = true;
      } else {
        map.easeTo({ center: lngLat });
      }
    },
    destroy(): void {
      marker?.remove();
      map.remove();
    },
  };
}
