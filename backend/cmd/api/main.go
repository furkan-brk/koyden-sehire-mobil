package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"
	"github.com/golang-migrate/migrate/v4"
	"github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"

	"github.com/koydensehire/backend/internal/admin"
	"github.com/koydensehire/backend/internal/audit"
	"github.com/koydensehire/backend/internal/auth"
	"github.com/koydensehire/backend/internal/categories"
	"github.com/koydensehire/backend/internal/config"
	"github.com/koydensehire/backend/internal/database"
	device_tokens "github.com/koydensehire/backend/internal/device_tokens"
	"github.com/koydensehire/backend/internal/farmer_applications"
	"github.com/koydensehire/backend/internal/farmers"
	"github.com/koydensehire/backend/internal/favorites"
	"github.com/koydensehire/backend/internal/invites"
	"github.com/koydensehire/backend/internal/middleware"
	"github.com/koydensehire/backend/internal/notifications"
	"github.com/koydensehire/backend/internal/otp"
	"github.com/koydensehire/backend/internal/products"
	"github.com/koydensehire/backend/internal/reports"
	"github.com/koydensehire/backend/internal/uploads"
	"github.com/koydensehire/backend/internal/users"
	"github.com/koydensehire/backend/internal/wellknown"
	"github.com/koydensehire/backend/pkg/sms"
	pkgstorage "github.com/koydensehire/backend/pkg/storage"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("loading config: %v", err)
	}

	db, err := database.NewPostgres(cfg.Database.URL, cfg.Database.MaxConnections, cfg.Database.MaxIdle)
	if err != nil {
		log.Fatalf("connecting to postgres: %v", err)
	}
	defer db.Close()
	log.Println("connected to postgres")

	rdb, err := database.NewRedis(cfg.Redis.URL, cfg.Redis.Password)
	if err != nil {
		log.Fatalf("connecting to redis: %v", err)
	}
	defer rdb.Close()
	log.Println("connected to redis")

	if cfg.App.AutoMigrate {
		driver, err := postgres.WithInstance(db.DB, &postgres.Config{})
		if err != nil {
			log.Fatalf("creating migrate driver: %v", err)
		}
		m, err := migrate.NewWithDatabaseInstance("file://migrations", "postgres", driver)
		if err != nil {
			log.Fatalf("creating migrate instance: %v", err)
		}
		if err := m.Up(); err != nil && err != migrate.ErrNoChange {
			log.Fatalf("running migrations: %v", err)
		}
		log.Println("migrations applied")
	}

	// Treat placeholder values (containing "<" or "your-") as unconfigured.
	storageConfigured := cfg.Storage.Endpoint != "" &&
		!strings.Contains(cfg.Storage.Endpoint, "<") &&
		cfg.Storage.AccessKey != "" &&
		!strings.HasPrefix(cfg.Storage.AccessKey, "your-") &&
		cfg.Storage.SecretKey != "" &&
		!strings.HasPrefix(cfg.Storage.SecretKey, "your-")
	log.Printf("app_env=%s storage_provider=%s storage_configured=%v", cfg.App.Env, cfg.Storage.Provider, storageConfigured)

	var storageProvider pkgstorage.Provider
	if storageConfigured {
		storageProvider, err = pkgstorage.NewR2Provider(
			cfg.Storage.Endpoint,
			cfg.Storage.PresignEndpoint,
			cfg.Storage.AccessKey,
			cfg.Storage.SecretKey,
			cfg.Storage.Bucket,
			cfg.Storage.PublicURL,
		)
		if err != nil {
			if cfg.App.Env == "development" {
				log.Printf("warning: R2 storage init failed (%v) — using dev placeholder storage", err)
				storageProvider = &pkgstorage.DevProvider{}
			} else {
				log.Fatalf("storage provider init failed (production requires real storage config): %v", err)
			}
		} else if cfg.App.Env == "development" {
			if r2, ok := storageProvider.(*pkgstorage.R2Provider); ok {
				if err := r2.EnsureBucketExists(context.Background()); err != nil {
					log.Printf("warning: could not ensure local minio bucket: %v", err)
				} else {
					log.Println("local minio bucket ensured")
				}
			}
		}
	} else if cfg.App.Env == "development" {
		log.Printf("warning: storage credentials not configured — using dev placeholder storage")
		storageProvider = &pkgstorage.DevProvider{}
	} else {
		log.Fatalf("storage credentials not configured (S3_ENDPOINT, S3_ACCESS_KEY, S3_SECRET_KEY are required in production)")
	}

	var smsProvider sms.Provider
	if cfg.App.Env == "development" && (cfg.SMS.Username == "" || cfg.SMS.Password == "") {
		smsProvider = &sms.DevProvider{}
	} else {
		smsProvider = sms.NewNetgsmProvider(cfg.SMS.Username, cfg.SMS.Password, cfg.SMS.Header)
	}

	webhookSvc := notifications.NewWebhookService(cfg.N8N.WebhookURL, cfg.N8N.WebhookSecret)
	notifSvc := notifications.NewService(webhookSvc)

	fcmClient := notifications.NewFCMClient(cfg.FCM.ProjectID, cfg.FCM.ServiceAccountJSON)
	dtRepo := device_tokens.NewRepository(db)
	notifRepo := notifications.NewNotifRepository(db)
	pushSvc := notifications.NewPushService(dtRepo, notifRepo, fcmClient, smsProvider)
	dtHandler := device_tokens.NewHandler(dtRepo)
	notifHandler := notifications.NewHandler(notifRepo)

	authRepo := auth.NewRepository(db)
	authSvc := auth.NewService(authRepo, rdb, cfg.JWT.Secret, cfg.JWT.AccessTokenExpiry, cfg.JWT.RefreshTokenExpiry)
	authSvc.SetSMSProvider(smsProvider, cfg.App.Env)
	authHandler := auth.NewHandler(authSvc)
	authHandler.SetPushNotifier(pushSvc)

	otpRepo := otp.NewRepository(db)
	otpSvc := otp.NewService(otpRepo, rdb, smsProvider, cfg.OTP.ExpirySeconds, cfg.OTP.MaxAttempts, cfg.OTP.ResendCooldownSeconds, cfg.App.Env)
	otpHandler := otp.NewHandler(otpSvc)

	userRepo := users.NewRepository(db)
	userSvc := users.NewService(userRepo)
	userHandler := users.NewHandler(userSvc)

	catRepo := categories.NewRepository(db)
	catSvc := categories.NewService(catRepo)
	catHandler := categories.NewHandler(catSvc)

	productRepo := products.NewRepository(db, cfg.Storage.PublicURL)
	productSvc := products.NewService(productRepo, db, storageProvider, cfg.Storage.PublicURL, cfg.App.Env)
	productHandler := products.NewHandler(productSvc)

	inviteRepo := invites.NewRepository(db)
	inviteSvc := invites.NewService(inviteRepo)
	inviteHandler := invites.NewHandler(inviteSvc)

	appRepo := farmer_applications.NewRepository(db)
	appHandler := farmer_applications.NewHandler(appRepo, rdb, db, storageProvider, cfg.App.Env)

	farmerRepo := farmers.NewRepository(db, cfg.Storage.PublicURL)
	farmerSvc := farmers.NewService(farmerRepo)
	farmerHandler := farmers.NewHandler(farmerSvc)
	farmerHandler.SetPushNotifier(pushSvc)

	uploadSvc := uploads.NewService(storageProvider, productRepo)
	uploadHandler := uploads.NewHandler(uploadSvc)
	productHandler.SetPushNotifier(pushSvc)

	favRepo := favorites.NewRepository(db, cfg.Storage.PublicURL)
	favSvc := favorites.NewService(favRepo)
	favHandler := favorites.NewHandler(favSvc)

	reportRepo := reports.NewRepository(db)
	reportSvc := reports.NewService(reportRepo)
	reportHandler := reports.NewHandler(reportSvc)

	auditRepo := audit.NewRepository(db)
	adminRepo := admin.NewRepository(db)
	adminSvc := admin.NewService(adminRepo, db, storageProvider, cfg.App.Env, auditRepo)
	adminHandler := admin.NewHandler(adminSvc, db, notifSvc, auditRepo)
	adminHandler.SetPushNotifier(pushSvc)

	// Password reset: auth service'e users repository'yi inject et
	authSvc.SetUserRepo(userRepo)

	// Account deletion: users service'e audit repo ve Redis'i inject et
	userSvc.SetDeps(auditRepo, rdb)

	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			return c.Status(500).JSON(fiber.Map{
				"success": false,
				"error":   fiber.Map{"code": "INTERNAL_ERROR", "message": err.Error()},
			})
		},
	})

	app.Use(recover.New())
	app.Use(logger.New())
	app.Use(middleware.CORS(cfg.App.CORSOrigins))

	// App Links / Universal Links domain doğrulama dosyaları (/api/v1 dışında, auth yok).
	// Deploy notu: koydensehire.com'u karşılayan reverse proxy /.well-known/* isteklerini
	// redirect'siz olarak bu API'ye yönlendirmeli.
	wkHandler := wellknown.NewHandler(cfg.DeepLink.AndroidPackage, cfg.DeepLink.AndroidSHA256Certs, cfg.DeepLink.AppleAppID)
	app.Get("/.well-known/assetlinks.json", wkHandler.AssetLinks)
	app.Get("/.well-known/apple-app-site-association", wkHandler.AppleAppSiteAssociation)
	app.Get("/apple-app-site-association", wkHandler.AppleAppSiteAssociation)

	requireAuth := middleware.RequireAuth(db, cfg.JWT.Secret)
	requireFarmer := middleware.RequireRole("farmer")
	requireAdmin := middleware.RequireRole("admin")
	requireCustomer := middleware.RequireRole("customer")
	requireActive := middleware.RequireActiveUser()

	api := app.Group("/api/v1")

	api.Get("/health", func(c *fiber.Ctx) error {
		dbStatus := "ok"
		if err := db.PingContext(context.Background()); err != nil {
			dbStatus = "error"
		}
		redisStatus := "ok"
		if err := rdb.Ping(context.Background()).Err(); err != nil {
			redisStatus = "error"
		}

		status := "ok"
		httpStatus := 200
		if dbStatus != "ok" || redisStatus != "ok" {
			status = "error"
			httpStatus = 503
		}

		return c.Status(httpStatus).JSON(fiber.Map{
			"status":   status,
			"database": dbStatus,
			"redis":    redisStatus,
			"version":  "1.0.0",
		})
	})

	api.Post("/otp/send", middleware.OTPSendRateLimit(rdb), otpHandler.Send)
	api.Post("/otp/verify", otpHandler.Verify)
	api.Post("/auth/login", middleware.LoginRateLimit(rdb), authHandler.Login)
	api.Post("/auth/refresh", authHandler.Refresh)
	api.Post("/auth/register/customer", middleware.RegisterRateLimit(rdb), authHandler.RegisterCustomer)
	api.Post("/auth/forgot-password", middleware.ForgotPasswordRateLimit(rdb), authHandler.ForgotPassword)
	api.Post("/auth/reset-password", authHandler.ResetPassword)
	api.Get("/categories", catHandler.List)
	api.Get("/products", productHandler.List)
	api.Get("/products/:id", productHandler.GetByID)
	api.Get("/farmers", farmerHandler.ListPublic)
	api.Get("/farmers/:id", farmerHandler.GetPublic)
	api.Get("/farmers/:id/products", func(c *fiber.Ctx) error {
		id := c.Params("id")
		prods, err := productSvc.ListByFarmerPublic(id)
		if err != nil {
			return c.Status(404).JSON(fiber.Map{"success": false, "error": fiber.Map{"code": "NOT_FOUND", "message": "Çiftçi bulunamadı"}})
		}
		return c.JSON(fiber.Map{"success": true, "data": prods})
	})
	api.Get("/invites/validate", middleware.InviteValidateRateLimit(rdb), inviteHandler.Validate)

	api.Post("/farmer-applications", appHandler.Create)
	api.Post("/uploads/application-video/presigned-url", middleware.VideoPresignRateLimit(rdb), appHandler.VideoPresign)

	// Reports — public route, JWT optional, IP rate-limited (3/hour)
	api.Post("/reports", middleware.ReportRateLimit(rdb), middleware.OptionalAuth(db, cfg.JWT.Secret), reportHandler.Submit)

	fm := []fiber.Handler{requireAuth, requireFarmer, requireActive}
	farmer := api.Group("/farmer")
	farmer.Get("/dashboard", append(fm, farmerHandler.GetDashboard)...)
	farmer.Get("/profile", append(fm, userHandler.GetProfile)...)
	farmer.Put("/profile", append(fm, userHandler.UpdateProfile)...)
	farmer.Get("/products", append(fm, productHandler.FarmerList)...)
	farmer.Post("/products", append(fm, productHandler.FarmerCreate)...)
	farmer.Get("/products/:id", append(fm, productHandler.FarmerGetByID)...)
	farmer.Put("/products/:id", append(fm, productHandler.FarmerUpdate)...)
	farmer.Post("/products/:id/complete", append(fm, productHandler.FarmerComplete)...)
	farmer.Patch("/products/:id/status", append(fm, productHandler.FarmerUpdateStatus)...)
	farmer.Get("/invites", append(fm, inviteHandler.FarmerInvites)...)
	farmer.Post("/uploads/product-image", append(fm, uploadHandler.UploadProductImage)...)
	farmer.Post("/uploads/product-image/presign", append(fm, uploadHandler.GetProductImagePresignedURL)...)
	farmer.Post("/uploads/profile-image", append(fm, uploadHandler.UploadProfileImage)...)
	farmer.Post("/push-token", append(fm, dtHandler.Upsert)...)
	farmer.Delete("/push-token", append(fm, dtHandler.Remove)...)
	farmer.Get("/notifications", append(fm, notifHandler.List)...)
	farmer.Patch("/notifications/read-all", append(fm, notifHandler.MarkAllRead)...)
	farmer.Patch("/notifications/:id/read", append(fm, notifHandler.MarkRead)...)
	farmer.Delete("/account", append(fm, userHandler.DeleteFarmerAccount)...)

	cm := []fiber.Handler{requireAuth, requireCustomer, requireActive}
	customerGroup := api.Group("/customer")
	customerGroup.Get("/profile", append(cm, userHandler.GetCustomerProfile)...)
	customerGroup.Put("/profile", append(cm, userHandler.UpdateCustomerProfile)...)
	customerGroup.Post("/push-token", append(cm, dtHandler.Upsert)...)
	customerGroup.Delete("/push-token", append(cm, dtHandler.Remove)...)
	customerGroup.Get("/notifications", append(cm, notifHandler.List)...)
	customerGroup.Patch("/notifications/read-all", append(cm, notifHandler.MarkAllRead)...)
	customerGroup.Patch("/notifications/:id/read", append(cm, notifHandler.MarkRead)...)
	// Favorites: accessible by customers and farmers (farmers can favourite
	// products while browsing the marketplace in customer mode).
	favMiddleware := []fiber.Handler{
		requireAuth,
		middleware.RequireAnyRole("customer", "farmer"),
		requireActive,
	}
	customerGroup.Post("/uploads/profile-image", append(cm, uploadHandler.UploadProfileImage)...)
	customerGroup.Get("/favorites", append(favMiddleware, favHandler.List)...)
	customerGroup.Post("/favorites/:productId", append(favMiddleware, favHandler.Add)...)
	customerGroup.Delete("/favorites/:productId", append(favMiddleware, favHandler.Remove)...)
	customerGroup.Delete("/account", append(cm, userHandler.DeleteCustomerAccount)...)

	adminGroup := api.Group("/admin", requireAuth, requireAdmin)
	adminGroup.Get("/dashboard", adminHandler.Dashboard)
	adminGroup.Get("/analytics/city-density", adminHandler.CityDensity)
	adminGroup.Get("/analytics/invite-network", adminHandler.InviteNetwork)
	adminGroup.Get("/applications", adminHandler.ListApplications)
	adminGroup.Get("/applications/:id", adminHandler.GetApplication)
	adminGroup.Post("/applications/:id/approve", adminHandler.ApproveApplication)
	adminGroup.Post("/applications/:id/reject", adminHandler.RejectApplication)
	adminGroup.Post("/applications/:id/request-video", adminHandler.RequestVideo)
	adminGroup.Get("/farmers", farmerHandler.AdminList)
	adminGroup.Get("/farmers/:id", farmerHandler.AdminGetByID)
	adminGroup.Post("/farmers/:id/suspend", farmerHandler.AdminSuspend)
	adminGroup.Post("/farmers/:id/reactivate", farmerHandler.AdminReactivate)
	adminGroup.Patch("/farmers/:id/founding", farmerHandler.AdminSetFounding)
	adminGroup.Patch("/farmers/:id/invite-quota", farmerHandler.AdminUpdateInviteQuota)
	adminGroup.Get("/products", productHandler.AdminList)
	adminGroup.Get("/products/:id", productHandler.AdminGetByID)
	adminGroup.Post("/products/:id/approve", productHandler.AdminApprove)
	adminGroup.Post("/products/:id/reject", productHandler.AdminReject)
	adminGroup.Post("/products/:id/hide", productHandler.AdminHide)
	adminGroup.Delete("/products/:id", productHandler.AdminDelete)
	adminGroup.Get("/categories", catHandler.AdminList)
	adminGroup.Post("/categories", catHandler.Create)
	adminGroup.Put("/categories/:id", catHandler.Update)
	adminGroup.Delete("/categories/:id", catHandler.Delete)
	adminGroup.Get("/audit-logs", adminHandler.ListAuditLogs)
	adminGroup.Get("/reports", reportHandler.AdminList)
	adminGroup.Patch("/reports/:id/review", reportHandler.AdminReview)

	// Start draft products cleanup worker (checks every hour)
	productSvc.StartDraftCleanupWorker(context.Background(), 1*time.Hour)

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	go func() {
		addr := fmt.Sprintf(":%s", cfg.App.Port)
		log.Printf("starting server on %s", addr)
		if err := app.Listen(addr); err != nil {
			log.Fatalf("server error: %v", err)
		}
	}()

	<-quit
	log.Println("shutting down server...")
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	_ = ctx
	app.Shutdown()
	log.Println("server stopped")
}
