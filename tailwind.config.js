/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./web/templates/**/*.{html,tmpl}",
    "./internal/templates/**/*.{html,tmpl}",
    "./web/static/js/**/*.{js,ts}",
  ],
  theme: {
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
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
  ],
}