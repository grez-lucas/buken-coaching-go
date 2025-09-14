package email

import (
	"crypto/tls"
	"fmt"
	"html/template"
	"log/slog"
	"net/smtp"
	"path/filepath"
	"regexp"
	"strings"
	textTemplate "text/template"
	"time"

	"github.com/grez-lucas/buken-coaching-go/internal/config"
)

type SMTPService struct {
	config        *config.SMTP
	htmlTemplates *template.Template
	textTemplates *textTemplate.Template
}

// ConsultationConfirmationData holds data for confirmed consultation emails (commitment 8+)
type ConsultationConfirmationData struct {
	Name            string
	Email           string
	Goal            string
	Timeframe       string
	Commitment      int
	Experience      string
	AppointmentDate string
	AppointmentTime string
	CalendarLink    string
}

// ConsultationReviewData holds data for manual review emails (commitment 7 and below)
type ConsultationReviewData struct {
	Name       string
	Email      string
	Goal       string
	Timeframe  string
	Commitment int
	Experience string
}

// CoachNotificationData holds data for coach notification emails
type CoachNotificationData struct {
	// Client information
	Name       string
	Email      string
	Phone      string
	Goal       string
	Timeframe  string
	Commitment int
	Experience string

	// Submission details
	SubmittedAt string
	IsQualified bool

	// Appointment details (only for qualified clients)
	AppointmentDate string
	AppointmentTime string
	MeetingLink     string
}

// ReminderData holds data for appointment reminder emails
type ReminderData struct {
	Name            string
	AppointmentDate string
	AppointmentTime string
	MeetingLink     string
	HoursUntil      int
}

// FormSubmission represents the raw form data from appointments page
type FormSubmission struct {
	Name       string
	Email      string
	Phone      string
	Goal       string // "fat-loss", "muscle-gain", etc.
	Timeframe  string // "3-months", "6-months", etc.
	Commitment int    // 1-10
	Experience string // "beginner", "intermediate", etc.
}

// Helper functions to translate form values to human-readable format
func translateGoal(goal string) string {
	goals := map[string]string{
		"fat-loss":      "Pérdida de grasa",
		"muscle-gain":   "Ganancia muscular",
		"strength":      "Aumento de fuerza",
		"recomposition": "Recomposición corporal",
		"performance":   "Rendimiento atlético",
		"lifestyle":     "Cambio de estilo de vida",
	}
	if translated, ok := goals[goal]; ok {
		return translated
	}
	return goal
}

func translateTimeframe(timeframe string) string {
	timeframes := map[string]string{
		"3-months":  "3 meses",
		"6-months":  "6 meses",
		"12-months": "12 meses",
		"long-term": "Más de 12 meses",
	}
	if translated, ok := timeframes[timeframe]; ok {
		return translated
	}
	return timeframe
}

func translateExperience(experience string) string {
	experiences := map[string]string{
		"beginner":     "Principiante (0-1 año)",
		"intermediate": "Intermedio (1-3 años)",
		"advanced":     "Avanzado (3+ años)",
		"athlete":      "Atleta/Competidor",
	}
	if translated, ok := experiences[experience]; ok {
		return translated
	}
	return experience
}

// NewConsultationConfirmationData creates email data for qualified clients (commitment 8+)
func NewConsultationConfirmationData(form FormSubmission, appointmentDate, appointmentTime, calendarLink string) ConsultationConfirmationData {
	return ConsultationConfirmationData{
		Name:            form.Name,
		Email:           form.Email,
		Goal:            translateGoal(form.Goal),
		Timeframe:       translateTimeframe(form.Timeframe),
		Commitment:      form.Commitment,
		Experience:      translateExperience(form.Experience),
		AppointmentDate: appointmentDate,
		AppointmentTime: appointmentTime,
		CalendarLink:    calendarLink,
	}
}

// NewConsultationReviewData creates email data for manual review clients (commitment 7 and below)
func NewConsultationReviewData(form FormSubmission) ConsultationReviewData {
	return ConsultationReviewData{
		Name:       form.Name,
		Email:      form.Email,
		Goal:       translateGoal(form.Goal),
		Timeframe:  translateTimeframe(form.Timeframe),
		Commitment: form.Commitment,
		Experience: translateExperience(form.Experience),
	}
}

// NewCoachNotificationData creates notification email data for the coach
func NewCoachNotificationData(form FormSubmission, submittedAt time.Time, appointmentDate, appointmentTime, meetingLink string) CoachNotificationData {
	isQualified := form.Commitment >= 8

	data := CoachNotificationData{
		Name:        form.Name,
		Email:       form.Email,
		Phone:       form.Phone,
		Goal:        translateGoal(form.Goal),
		Timeframe:   translateTimeframe(form.Timeframe),
		Commitment:  form.Commitment,
		Experience:  translateExperience(form.Experience),
		SubmittedAt: submittedAt.Format("02/01/2006 15:04"),
		IsQualified: isQualified,
	}

	// Only add appointment details if qualified
	if isQualified {
		data.AppointmentDate = appointmentDate
		data.AppointmentTime = appointmentTime
		data.MeetingLink = meetingLink
	}

	return data
}

// NewSMTPService instantiates a new SMTPService with a given SMTP configuration.
// It loads email templates from the specified directory.
func NewSMTPService(cfg *config.SMTP, templatesDir string) (*SMTPService, error) {
	service := &SMTPService{config: cfg}

	if err := service.loadTemplates(templatesDir); err != nil {
		return nil, fmt.Errorf("failed to load email templates: %w", err)
	}

	return service, nil
}

// loadTemplates loads HTML and text email templates from the specified directory
func (s *SMTPService) loadTemplates(templatesDir string) error {
	// Load HTML templates
	htmlPattern := filepath.Join(templatesDir, "*.html")
	htmlTemplates, err := template.ParseGlob(htmlPattern)
	if err != nil {
		return fmt.Errorf("failed to parse HTML templates: %w", err)
	}
	s.htmlTemplates = htmlTemplates

	// Load text templates
	textPattern := filepath.Join(templatesDir, "*.txt")
	textTemplates, err := textTemplate.ParseGlob(textPattern)
	if err != nil {
		return fmt.Errorf("failed to parse text templates: %w", err)
	}
	s.textTemplates = textTemplates

	return nil
}

// executeTemplate renders both HTML and text versions of a template
func (s *SMTPService) executeTemplate(templateName string, data any) (htmlBody, textBody string, err error) {
	// Execute HTML template
	var htmlBuf, textBuf strings.Builder

	htmlTemplateName := templateName + ".html"
	if s.htmlTemplates.Lookup(htmlTemplateName) == nil {
		return "", "", fmt.Errorf("HTML template %s not found", htmlTemplateName)
	}
	if err := s.htmlTemplates.ExecuteTemplate(&htmlBuf, htmlTemplateName, data); err != nil {
		return "", "", fmt.Errorf("failed to execute HTML template: %w", err)
	}

	// Execute text template
	textTemplateName := templateName + ".txt"
	if s.textTemplates.Lookup(textTemplateName) == nil {
		return "", "", fmt.Errorf("text template %s not found", textTemplateName)
	}
	if err := s.textTemplates.ExecuteTemplate(&textBuf, textTemplateName, data); err != nil {
		return "", "", fmt.Errorf("failed to execute text template: %w", err)
	}

	return htmlBuf.String(), textBuf.String(), nil
}

// SendConsultationConfirmation sends a confirmation email to qualified clients (commitment 8+)
func (s *SMTPService) SendConsultationConfirmation(data ConsultationConfirmationData) error {
	htmlBody, textBody, err := s.executeTemplate("consultation_confirmation", data)
	if err != nil {
		return fmt.Errorf("failed to render consultation confirmation template: %w", err)
	}

	subject := "✅ Consulta Confirmada - LB Coaching"
	return s.sendEmailWithRetry(data.Email, subject, htmlBody, textBody, 3)
}

// SendConsultationReview sends a review email to clients needing manual evaluation (commitment 7 and below)
func (s *SMTPService) SendConsultationReview(data ConsultationReviewData) error {
	htmlBody, textBody, err := s.executeTemplate("consultation_review", data)
	if err != nil {
		return fmt.Errorf("failed to render consultation review template: %w", err)
	}

	subject := "⏳ Evaluación en Proceso - LB Coaching"
	return s.sendEmailWithRetry(data.Email, subject, htmlBody, textBody, 3)
}

// SendCoachNotification sends a notification email to the coach when someone submits a consultation request
func (s *SMTPService) SendCoachNotification(data CoachNotificationData, coachEmail string) error {
	htmlBody, textBody, err := s.executeTemplate("coach_notification", data)
	if err != nil {
		return fmt.Errorf("failed to render coach notification template: %w", err)
	}

	var subject string
	if data.IsQualified {
		subject = fmt.Sprintf("🎯 Nueva Consulta CALIFICADA - %s (Compromiso: %d/10)", data.Name, data.Commitment)
	} else {
		subject = fmt.Sprintf("⚠️ Revisión Manual Requerida - %s (Compromiso: %d/10)", data.Name, data.Commitment)
	}

	return s.sendEmailWithRetry(coachEmail, subject, htmlBody, textBody, 3)
}

// SendAppointmentReminder sends a reminder email before an appointment (future use)
func (s *SMTPService) SendAppointmentReminder(data ReminderData) error {
	htmlBody, textBody, err := s.executeTemplate("appointment_reminder", data)
	if err != nil {
		return fmt.Errorf("failed to render appointment reminder template: %w", err)
	}

	subject := fmt.Sprintf("🔔 Recordatorio: Tu consulta es en %d horas - LB Coaching", data.HoursUntil)
	return s.sendEmailWithRetry(data.Name, subject, htmlBody, textBody, 3)
}

// sendEmail sends an email to a single recipient.
func (s *SMTPService) sendEmail(to, subject, htmlBody, textBody string) error {
	// Validate recipient email
	if err := validateEmail(to); err != nil {
		return fmt.Errorf("invalid recipient email: %w", err)
	}

	// Handle both HTML and plain text
	auth := smtp.PlainAuth("", s.config.Username, s.config.Password, s.config.Host)
	addr := fmt.Sprintf("%s:%d", s.config.Host, s.config.Port)
	message := buildMultipartMessage(s.config.From, to, subject, textBody, htmlBody)

	if s.config.Port == 465 && s.config.UseTLS {
		tlsConfig := &tls.Config{
			ServerName: s.config.Host,
		}
		conn, err := tls.Dial("tcp", addr, tlsConfig)
		if err != nil {
			return err
		}
		client, err := smtp.NewClient(conn, s.config.Host)
		if err != nil {
			return err
		}
		defer client.Quit()
		if err := client.Auth(auth); err != nil {
			return err
		}
		if err := client.Mail(s.config.From); err != nil {
			return err
		}
		if err := client.Rcpt(to); err != nil {
			return err
		}

		// Get io.WriteCloser for message body
		wc, err := client.Data()
		if err != nil {
			return err
		}
		defer wc.Close()

		_, err = wc.Write(message)
		if err != nil {
			return err
		}
		return nil

	} else {
		return smtp.SendMail(addr, auth, s.config.From, []string{to}, message)
	}
}

func buildMultipartMessage(from, to, subject, textBody, htmlBody string) []byte {
	boundary := fmt.Sprintf("boundary_%d", time.Now().Unix())

	headers := fmt.Sprintf("From: %s\r\n", from)
	headers += fmt.Sprintf("To: %s\r\n", to)
	headers += fmt.Sprintf("Subject: %s\r\n", subject)
	headers += "MIME-Version: 1.0\r\n"
	headers += fmt.Sprintf("Content-Type: multipart/alternative; boundary=\"%s\"\r\n", boundary)
	headers += "\r\n"

	body := fmt.Sprintf("--%s\r\n", boundary)

	// Plain text part
	body += "Content-Type: text/plain; charset=\"UTF-8\"\r\n"
	body += "\r\n"
	body += fmt.Sprintf("%s\r\n", textBody)
	body += "\r\n"

	// HTML part
	body += fmt.Sprintf("--%s\r\n", boundary)
	body += "Content-Type: text/html; charset=\"UTF-8\"\r\n"
	body += "\r\n"
	body += fmt.Sprintf("%s\r\n", htmlBody)
	body += "\r\n"

	// End boundary
	body += fmt.Sprintf("--%s--\r\n", boundary)

	message := headers + body
	return []byte(message)
}

func (s *SMTPService) sendEmailWithRetry(to, subject, htmlBody, textBody string, maxRetries int) error {
	err := s.sendEmail(to, subject, htmlBody, textBody)
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if err == nil {
			slog.Info("Email sent successfully",
				slog.Int("attempt", attempt),
				slog.String("recipient", to),
			)
			return nil
		}

		if attempt < maxRetries {
			delay := time.Duration(attempt+1) * 2 * time.Second
			slog.Warn("Retrying after delay", slog.String("delay", delay.String()))
			time.Sleep(delay)
		}

	}
	return fmt.Errorf("failed to send email after %d attempts: %w", maxRetries+1, err)
}

// validateEmail checks if an email address is valid using a comprehensive regex pattern
func validateEmail(email string) error {
	if email == "" {
		return fmt.Errorf("email address cannot be empty")
	}

	// RFC 5322 compliant email regex pattern (simplified but comprehensive)
	// Allows most valid email formats while blocking obvious invalid ones
	pattern := `^[a-zA-Z0-9.!#$%&'*+/=?^_` + "`" + `{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$`

	regex := regexp.MustCompile(pattern)
	if !regex.MatchString(email) {
		return fmt.Errorf("email address format is invalid: %s", email)
	}

	// Additional checks for common issues
	if len(email) > 254 { // Max email length per RFC
		return fmt.Errorf("email address is too long (max 254 characters)")
	}

	return nil
}
