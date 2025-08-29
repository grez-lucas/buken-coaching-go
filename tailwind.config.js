/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./web/templates/**/*.{html,tmpl}",
    "./internal/templates/**/*.{html,tmpl}",
    "./web/static/js/**/*.{js,ts}",
  ],
  theme: {
    screens: {
      sm: "480px",
      md: "768px",
      lg: "976px",
      xl: "1440px",
    },
    colors: {
      main: "#227447",
      secondary: "#252525",
      accent1: "#C0392B",
      accent2: "#F39C12",
      neutral1: "#FFFFFF",
      neutral2: "#F5F5F5",
      neutral3: "#CCCCCC",
      transparent: "transparent",
      white: {
        DEFAULT: "#FFFFFF",
      },
      black: "#000000",
      gray: "#CCCCCC",
      dark: {
        DEFAULT: "#262626",
        500: "#737373",
      },
      red: {
        DEFAULT: "#C0392B",
        500: "#E74C3C",
        600: "#C0392B",
      },
      slate: {
        DEFAULT: "#252525",
        100: "#f1f5f9",
        200: "#e2e8f0",
        300: "#cbd5e1",
        400: "#94a3b8",
        500: "#64748b",
        600: "#475569",
        700: "#334155",
        800: "#1e293b",
        900: "#0f172a",
      },
      neutral: {
        DEFAULT: "#CCCCCC",
        100: "#f1f5f9",
        200: "#e2e8f0",
        300: "#cbd5e1",
        400: "#94a3b8",
        500: "#64748b",
        600: "#475569",
        700: "#334155",
        800: "#1e293b",
        900: "#0f172a",
      }
    },
    extend: {
      colors: {
        main: "#227447",
        secondary: "#252525",
        accent: {
          DEFAULT: "#fbbf24",
          dark: "#f59e0b",
        },
      },
      fontFamily: {
        sans: ["Montserrat", "sans-serif"],
        serif: ["Roboto Slab", "serif"],
        display: ["Oswald", "sans-serif"],
        custom: ["Poppins", "sans-serif"],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
    require("tw-elements-react/dist/plugin.cjs"),
    require("tw-elements/dist/plugin.cjs")
  ],
}
