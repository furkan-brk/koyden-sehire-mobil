package otp

// AuditWriter is the subset of Repository used by Service for write-only audit
// operations. Extracted so tests can inject a no-op implementation.
type AuditWriter interface {
	InsertAudit(phone, purpose, ip, userAgent string) error
	MarkVerified(phone string) error
}
