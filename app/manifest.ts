// app/manifest.ts
import type { MetadataRoute } from 'next';

// Web App Manifest de la PWA (se sirve en /manifest.webmanifest).
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'RunTrack - Registro para Corredores',
    short_name: 'RunTrack',
    description: 'Centraliza y analiza tus entrenamientos de running',
    start_url: '/',
    display: 'standalone',
    background_color: '#ffffff',
    theme_color: '#ec4899', // Tono rosado / magenta deportivo
    icons: [
      { src: '/icons/icon-192x192.png', sizes: '192x192', type: 'image/png' },
      { src: '/icons/icon-512x512.png', sizes: '512x512', type: 'image/png' },
    ],
  };
}
