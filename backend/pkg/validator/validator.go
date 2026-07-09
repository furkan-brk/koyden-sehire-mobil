package validator

import (
	"errors"
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"
)

var validate = newValidator()

func newValidator() *validator.Validate {
	v := validator.New()
	// Report field names using their json tag so error messages match the
	// request payload instead of Go struct field names.
	v.RegisterTagNameFunc(func(fld reflect.StructField) string {
		name := strings.SplitN(fld.Tag.Get("json"), ",", 2)[0]
		if name == "-" {
			return ""
		}
		return name
	})
	return v
}

func Validate(s interface{}) error {
	return validate.Struct(s)
}

func ValidateField(field interface{}, tag string) error {
	return validate.Var(field, tag)
}

// InvalidFieldsMessage appends the offending json field names to base when
// err is a validation error, e.g. "Zorunlu alanlar eksik: city, district".
func InvalidFieldsMessage(err error, base string) string {
	var verrs validator.ValidationErrors
	if !errors.As(err, &verrs) || len(verrs) == 0 {
		return base
	}
	fields := make([]string, 0, len(verrs))
	for _, fe := range verrs {
		if f := fe.Field(); f != "" {
			fields = append(fields, f)
		}
	}
	if len(fields) == 0 {
		return base
	}
	return base + ": " + strings.Join(fields, ", ")
}
