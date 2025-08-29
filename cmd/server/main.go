package main

import (
	"fmt"
	"net/http"

	"github.com/a-h/templ"
	"github.com/grez-lucas/buken-coaching-go/web/templates"
)

func main() {
	component := templates.BaseLayout("Hello Main")
	http.Handle("/", templ.Handler(component))
	fmt.Printf("Listening on port :%d", 3000)
	http.ListenAndServe(":3000", nil)
}
