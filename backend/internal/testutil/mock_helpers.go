// Package testutil provides shared helpers and mock implementations for unit tests.
package testutil

import (
	"time"

	"golang.org/x/crypto/bcrypt"
)

// HashPassword returns a bcrypt hash of the given password at cost 10.
// Panics on error — only for use in tests.
func HashPassword(password string) string {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), 10)
	if err != nil {
		panic("testutil: bcrypt failed: " + err.Error())
	}
	return string(hash)
}

// TimeNow is a fixed time used in tests to keep assertions deterministic.
var TimeNow = time.Date(2024, 1, 15, 12, 0, 0, 0, time.UTC)
