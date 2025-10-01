import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

// Configuration for static landing page (GitHub Pages)
export default defineConfig({
  plugins: [react()],
  base: '/',
  build: {
    outDir: 'dist-static',
    emptyOutDir: true,
    rollupOptions: {
      input: path.resolve(__dirname, 'index-static.html')
    }
  }
})
