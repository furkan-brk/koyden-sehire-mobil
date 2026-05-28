package auth

// UserFinder is the read-side of the auth repository, extracted so Service can
// be tested without a real database.
type UserFinder interface {
	FindByPhone(phone string) (*User, error)
	FindByID(id string) (*User, error)
	CreateCustomer(fullName, phone, email, passwordHash string) (*User, error)
}
