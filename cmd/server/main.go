package main

import (
	"log"
	"log/slog"
	"net/http"
	"os"
	"time"

	"github.com/a-h/templ"
	"github.com/grez-lucas/buken-coaching-go/internal/config"
	"github.com/grez-lucas/buken-coaching-go/internal/email"
	"github.com/grez-lucas/buken-coaching-go/internal/middleware"
	"github.com/grez-lucas/buken-coaching-go/internal/templates"
	"github.com/joho/godotenv"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	if err := godotenv.Load(); err != nil {
		slog.Warn("Could not load .env file", slog.Any("error", err))
	}

	smtpConfig, err := config.NewSMTP()
	if err != nil {
		log.Fatal("SMTP config:", err)
	}

	smtpService, err := email.NewSMTPService(smtpConfig, "internal/templates/emails", logger)
	if err != nil {
		log.Fatal("Email service:", err)
	}

	emailHandler := email.NewEmailHandler(smtpService, smtpConfig.Username, logger)

	r := http.NewServeMux()

	// Serve static files
	static := http.FileServer(http.Dir("./web/static"))
	r.Handle("GET /static/", http.StripPrefix("/static/", static))

	// Serve templ templates
	r.Handle("/", templ.Handler(templates.IndexPage()))
	r.Handle("/about", templ.Handler(templates.AboutMe()))
	r.Handle("/appointments", templ.Handler(templates.Appointments()))
	r.Handle("/coaching", templ.Handler(templates.Coaching()))

	// Handle form submissions
	r.HandleFunc("/api/appointments", emailHandler.HandleAppointmentForm)

	srv := &http.Server{
		Handler:      middleware.Logging(logger, r),
		WriteTimeout: 10 * time.Second,
		ReadTimeout:  10 * time.Second,
		Addr:         ":3000",
	}

	logger.Info("Server listening", "port", 3000)

	srv.ListenAndServe()
}
