/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        primary: { DEFAULT: '#7C3AED', light: '#9D5CF6', dark: '#5B21B6', faint: '#EDE9FE' },
        brand:   { blue: '#60A5FA', ink: '#1A1208', muted: '#8B6F5E', bg: '#FDF6EC', card: '#F5EDE4', rust: '#C4522A' },
        sidebar: { bg: '#0F0A1E', border: '#1F1640', hover: '#1A1035', active: '#2D1B69' },
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
      opacity: {
        '3':  '0.03',
        '4':  '0.04',
        '8':  '0.08',
        '12': '0.12',
        '15': '0.15',
        '18': '0.18',
        '22': '0.22',
        '35': '0.35',
        '45': '0.45',
        '55': '0.55',
        '65': '0.65',
        '85': '0.85',
      },
    },
  },
  plugins: [],
}
