package main

import (
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/a-h/templ"
	"github.com/grez-lucas/buken-coaching-go/internal/middleware"
	"github.com/grez-lucas/buken-coaching-go/internal/templates"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	r := http.NewServeMux()

	// Serve static files
	static := http.FileServer(http.Dir("./web/static"))
	r.Handle("GET /static/", http.StripPrefix("/static/", static))

	// Serve templ templates
	r.Handle("/", templ.Handler(templates.IndexPage()))

	srv := &http.Server{
		Handler:      middleware.Logging(logger, r),
		WriteTimeout: 10 * time.Second,
		ReadTimeout:  10 * time.Second,
		Addr:         ":3000",
	}

	logger.Info("Server listening", "port", 3000)

	srv.ListenAndServe()
}
