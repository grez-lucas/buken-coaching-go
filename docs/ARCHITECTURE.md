# Architecture Notes

## Understanding Go Project Structure

`cmd/` Directory:

* Contains application entry points (main packages)

* Each subdirectory is a separate executable

* Keep minimal code here, just initialization

`internal/` Directory:

* Private packages only this module can import

* Prevents external projects from depending on internal implementation

* Good for hiding implementation details

`web/` Directory:

* Static assets served to browsers

* Templates for server-side rendering

* Keep organized by file type
