import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  // Configure as SPA - automatically handles fallback to index.html
  appType: 'spa',

  plugins: [react()],

  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      '@components': path.resolve(__dirname, './src/components'),
      '@pages': path.resolve(__dirname, './src/pages'),
      '@styles': path.resolve(__dirname, './src/styles'),
      '@contexts': path.resolve(__dirname, './src/contexts'),
      '@services': path.resolve(__dirname, './src/services'),
      '@utils': path.resolve(__dirname, './src/utils'),
      '@hooks': path.resolve(__dirname, './src/hooks'),
    }
  },

  server: {
    port: 5173,
    strictPort: false,
    open: false,
    proxy: {
      '/api': {
        target: 'http://localhost:3333',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '/api')
      }
    }
  },

  build: {
    outDir: 'dist',
    sourcemap: false,
    minify: 'terser',
    target: ['es2020', 'edge88', 'firefox78', 'chrome87', 'safari13'],
    // ARCHITECTURAL FIX: Aggressive code splitting for mobile performance
    chunkSizeWarningLimit: 300, // Warn if chunks exceed 300 KB
    rollupOptions: {
      output: {
        // ARCHITECTURAL FIX: Split heavy libraries into separate chunks
        // This allows mobile browsers to load only what's needed for each page
        manualChunks: (id) => {
          // CRITICAL FIX: Don't split React at all - let Vite handle it automatically
          // React must stay in the main vendor chunk to avoid circular dependencies

          // Router chunk
          if (id.includes('node_modules/react-router-dom')) {
            return 'router'
          }

          // HTTP client chunk
          if (id.includes('node_modules/axios')) {
            return 'http'
          }

          // Animation library chunk (large - only load when needed)
          if (id.includes('node_modules/framer-motion')) {
            return 'animations'
          }

          // HTML canvas library (199 KB!) - only for Black Mirror page
          if (id.includes('node_modules/html2canvas') ||
              id.includes('node_modules/dompurify')) {
            return 'canvas-utils'
          }

          // UI component chunks
          if (id.includes('node_modules/@headlessui') ||
              id.includes('node_modules/@heroicons')) {
            return 'ui-components'
          }

          // Form validation chunk
          if (id.includes('node_modules/react-hook-form') ||
              id.includes('node_modules/yup')) {
            return 'forms'
          }

          // Virtual scrolling (react-window) - critical for message list
          if (id.includes('node_modules/react-window') ||
              id.includes('node_modules/react-virtualized-auto-sizer')) {
            return 'virtualization'
          }

          // Other node_modules - split by size threshold
          if (id.includes('node_modules')) {
            // Extract package name from node_modules path
            const match = id.match(/node_modules\/([^\/]+)/)
            if (match && match[1]) {
              const packageName = match[1]

              // Large packages get their own chunks (if > 50 KB estimated)
              const largePackages = [
                '@react-oauth',
                '@stripe',
                'gsap',
                'matter-js',
                'motion',
                'ogl',
                'jspdf',
                'jspdf-autotable',
                'recharts',
                'date-fns',
                'lodash'
              ]

              if (largePackages.includes(packageName)) {
                return `vendor-${packageName}`
              }
            }

            // Everything else in generic vendor
            return 'vendor'
          }
        },

        // Generate smaller, cacheable chunks
        chunkFileNames: 'assets/[name]-[hash].js',
        entryFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash].[ext]'
      }
    },

    // Enable tree shaking
    treeshake: {
      preset: 'recommended',
      moduleSideEffects: false
    }
  },

  css: {
    preprocessorOptions: {
      scss: {
        additionalData: `@import "@/styles/variables.scss";`
      }
    }
  }
})
