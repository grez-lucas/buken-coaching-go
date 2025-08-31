/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./internal/templates/**/*.templ",
    "./internal/templates/**/*_templ.go",
    "./web/templates/**/*.{html,templ}",
    "./web/static/js/**/*.{js,ts}",
  ],
}