import react from '@vitejs/plugin-react';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  plugins: [react()],
  server: {
    // Local development: the .NET API runs on :5200 (dotnet run --project src/CocoRider.Api).
    proxy: {
      '/api': { target: 'http://localhost:5200', rewrite: (path) => path.replace(/^\/api/, '') },
    },
  },
  test: {
    environment: 'jsdom',
    setupFiles: ['./src/test-setup.ts'],
  },
});
