package email

import (
	"fmt"
	"log/slog"
	"net/http"
	"strconv"
	"time"
)

type EmailHandler struct {
	smtpService *SMTPService
	coachEmail  string
}

func NewEmailHandler(smtpService *SMTPService, coachEmail string) *EmailHandler {
	return &EmailHandler{
		smtpService: smtpService,
		coachEmail:  coachEmail,
	}
}

func (h *EmailHandler) HandleAppointmentForm(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse multipart form data
	if err := r.ParseMultipartForm(32 << 20); err != nil { // 32 MB max memory
		slog.Error("Failed to parse multipart form", slog.String("error", err.Error()))
		http.Error(w, "Invalid form data", http.StatusBadRequest)
		return
	}

	// Convert commitment string to int
	commitmentStr := r.FormValue("commitment")
	if commitmentStr == "" {
		slog.Error("Commitment value is required")
		http.Error(w, "Commitment level is required", http.StatusBadRequest)
		return
	}

	commitment, err := strconv.Atoi(commitmentStr)
	if err != nil || commitment < 1 || commitment > 10 {
		slog.Error("Invalid commitment value", slog.String("value", commitmentStr), slog.String("error", err.Error()))
		http.Error(w, "Commitment level must be between 1 and 10", http.StatusBadRequest)
		return
	}

	form := FormSubmission{
		Name:       r.FormValue("name"),
		Email:      r.FormValue("email"),
		Phone:      r.FormValue("phone"),
		Goal:       r.FormValue("goal"),
		Timeframe:  r.FormValue("timeframe"),
		Commitment: commitment,
		Experience: r.FormValue("experience"),
	}

	// Send emails
	if err := h.HandleConsultationSubmission(form); err != nil {
		slog.Error("Email sending failed", slog.String("error", err.Error()))
		http.Error(w, "Failed to send emails", http.StatusInternalServerError)
		return
	}

	// Return success response (JSON for AJAX)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"success": true, "message": "Form submitted successfully"}`))
}

func (h *EmailHandler) HandleConsultationSubmission(form FormSubmission) error {
	now := time.Now()

	if form.Commitment >= 8 {
		// Qualified client - send confirmation + schedule
		confirmData := NewConsultationConfirmationData(form, "", "", "")
		if err := h.smtpService.SendConsultationConfirmation(confirmData); err != nil {
			return fmt.Errorf("failed to send confirmation: %w", err)
		}

		// Notify coach (no appointment details)
		coachData := NewCoachNotificationData(form, now, "", "", "")
		return h.smtpService.SendCoachNotification(coachData, h.coachEmail)
	} else {
		// Manual review path
		reviewData := NewConsultationReviewData(form)
		if err := h.smtpService.SendConsultationReview(reviewData); err != nil {
			return fmt.Errorf("failed to send review notification: %w", err)
		}

		coachData := NewCoachNotificationData(form, now, "", "", "")
		return h.smtpService.SendCoachNotification(coachData, h.coachEmail)
	}
}
