package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
)

type SMTP struct {
	Host     string
	Port     uint16
	Username string
	Password string
	From     string
	UseTLS   bool
}

// NewSMTP creates a SMTP configuration based on the current available
// environment variables. It returns an error if env vars are not set
// or unavailable.
func NewSMTP() (*SMTP, error) {
	host, ok := os.LookupEnv("SMTP_HOST")
	if !ok {
		return nil, errors.New("no SMTP_HOST environment variable set")
	}

	portStr, ok := os.LookupEnv("SMTP_PORT")
	if !ok {
		return nil, errors.New("no SMTP_PORT environment variable set")
	}

	port, err := strconv.ParseInt(portStr, 10, 16)
	if err != nil {
		return nil, fmt.Errorf("failed to parse SMTP_PORT to uint16: %w", err)
	}

	username, ok := os.LookupEnv("SMTP_USER")
	if !ok {
		return nil, errors.New("no SMTP_USER environment variable set")
	}

	password, ok := os.LookupEnv("SMTP_PASSWORD")
	if !ok {
		return nil, errors.New("no SMTP_PASSWORD environment variable set")
	}

	from, ok := os.LookupEnv("SMTP_FROM")
	if !ok {
		return nil, errors.New("no SMTP_FROM environment variable set")
	}

	// Use TLS by default
	useTLS := true
	if useTLSStr, ok := os.LookupEnv("SMTP_USE_TLS"); ok {
		useTLS, err = strconv.ParseBool(useTLSStr)
		if err != nil {
			return nil, fmt.Errorf("failed to parse SMTP_USE_TLS environment variable to bool: %w", err)
		}
	}

	config := &SMTP{
		Host:     host,
		Port:     uint16(port),
		Username: username,
		Password: password,
		From:     from,
		UseTLS:   useTLS,
	}
	return config, nil
}
