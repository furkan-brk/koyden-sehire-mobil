// Package wellknown serves the /.well-known files required for
// Android App Links and iOS Universal Links domain verification.
package wellknown

import "github.com/gofiber/fiber/v2"

type Handler struct {
	androidPackage string
	sha256Certs    []string
	appleAppID     string
}

func NewHandler(androidPackage string, sha256Certs []string, appleAppID string) *Handler {
	return &Handler{
		androidPackage: androidPackage,
		sha256Certs:    sha256Certs,
		appleAppID:     appleAppID,
	}
}

// AssetLinks — GET /.well-known/assetlinks.json
// Fingerprint yapılandırılmamışsa 404 döner; Google'ın geçersiz bir dosyayı
// cache'lemesindense hiç sunmamak daha güvenli.
func (h *Handler) AssetLinks(c *fiber.Ctx) error {
	if len(h.sha256Certs) == 0 {
		return c.SendStatus(fiber.StatusNotFound)
	}
	c.Set("Content-Type", "application/json")
	return c.JSON([]fiber.Map{{
		"relation": []string{"delegate_permission/common.handle_all_urls"},
		"target": fiber.Map{
			"namespace":                "android_app",
			"package_name":             h.androidPackage,
			"sha256_cert_fingerprints": h.sha256Certs,
		},
	}})
}

// AppleAppSiteAssociation — GET /.well-known/apple-app-site-association
// Dosya uzantısız sunulur; Content-Type application/json olmalı.
func (h *Handler) AppleAppSiteAssociation(c *fiber.Ctx) error {
	if h.appleAppID == "" {
		return c.SendStatus(fiber.StatusNotFound)
	}
	c.Set("Content-Type", "application/json")
	return c.JSON(fiber.Map{
		"applinks": fiber.Map{
			"details": []fiber.Map{{
				"appIDs": []string{h.appleAppID},
				"components": []fiber.Map{
					{"/": "/apply"},
				},
			}},
		},
	})
}
