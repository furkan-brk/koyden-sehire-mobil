package storage

import (
	"context"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/aws/smithy-go"
)

type R2Provider struct {
	client          *s3.Client
	presigner       *s3.PresignClient
	putPresigner    *s3.PresignClient // uses presignEndpoint — client-accessible URL for PUT uploads
	bucket          string
	publicURL       string
}

// NewR2Provider creates an S3-compatible storage provider.
// presignEndpoint overrides the endpoint used for presigned PUT URLs so clients
// (e.g. Android emulator at 10.0.2.2) can reach the URL directly without the
// signature breaking. If empty it falls back to endpoint.
func NewR2Provider(endpoint, presignEndpoint, accessKey, secretKey, bucket, publicURL string) (*R2Provider, error) {
	resolverFor := func(ep string) aws.EndpointResolverWithOptions {
		return aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
			return aws.Endpoint{URL: ep}, nil
		})
	}

	regionFor := func(ep string) string {
		if strings.Contains(ep, "r2.cloudflarestorage.com") {
			return "auto"
		}
		return "us-east-1"
	}

	cfg, err := config.LoadDefaultConfig(context.Background(),
		config.WithEndpointResolverWithOptions(resolverFor(endpoint)),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
		config.WithRegion(regionFor(endpoint)),
	)
	if err != nil {
		return nil, fmt.Errorf("loading R2 config: %w", err)
	}

	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true
	})

	// If a separate presign endpoint is configured, build a dedicated client for it.
	// This client is only used to generate presigned PUT URLs — it never dials the endpoint itself.
	var putPresigner *s3.PresignClient
	if presignEndpoint != "" && presignEndpoint != endpoint {
		presignCfg, err := config.LoadDefaultConfig(context.Background(),
			config.WithEndpointResolverWithOptions(resolverFor(presignEndpoint)),
			config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
			config.WithRegion(regionFor(presignEndpoint)),
		)
		if err != nil {
			return nil, fmt.Errorf("loading presign config: %w", err)
		}
		presignClient := s3.NewFromConfig(presignCfg, func(o *s3.Options) {
			o.UsePathStyle = true
		})
		putPresigner = s3.NewPresignClient(presignClient)
	} else {
		putPresigner = s3.NewPresignClient(client)
	}

	return &R2Provider{
		client:       client,
		presigner:    s3.NewPresignClient(client),
		putPresigner: putPresigner,
		bucket:       bucket,
		publicURL:    strings.TrimRight(publicURL, "/"),
	}, nil
}

func (r *R2Provider) Upload(ctx context.Context, key string, file io.Reader, contentType string, size int64) (string, error) {
	_, err := r.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(r.bucket),
		Key:           aws.String(key),
		Body:          file,
		ContentType:   aws.String(contentType),
		ContentLength: aws.Int64(size),
	})
	if err != nil {
		return "", fmt.Errorf("uploading to R2: %w", err)
	}

	if isPublicKey(key) {
		return r.publicURL + "/" + key, nil
	}
	return key, nil
}

func (r *R2Provider) GeneratePresignedPutURL(ctx context.Context, key string, contentType string, metadata map[string]string, ttl time.Duration) (string, error) {
	input := &s3.PutObjectInput{
		Bucket:      aws.String(r.bucket),
		Key:         aws.String(key),
		ContentType: aws.String(contentType),
	}
	if len(metadata) > 0 {
		input.Metadata = metadata
	}
	req, err := r.putPresigner.PresignPutObject(ctx, input, s3.WithPresignExpires(ttl))
	if err != nil {
		return "", fmt.Errorf("generating presigned put URL: %w", err)
	}
	return req.URL, nil
}

func (r *R2Provider) GeneratePresignedGetURL(ctx context.Context, key string, ttl time.Duration) (string, error) {
	req, err := r.presigner.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(ttl))
	if err != nil {
		return "", fmt.Errorf("generating presigned get URL: %w", err)
	}
	return req.URL, nil
}

func (r *R2Provider) Delete(ctx context.Context, key string) error {
	_, err := r.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	})
	return err
}

func (r *R2Provider) Exists(ctx context.Context, key string) (bool, error) {
	_, err := r.client.HeadObject(ctx, &s3.HeadObjectInput{
		Bucket: aws.String(r.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		var apiErr smithy.APIError
		if errors.As(err, &apiErr) {
			if apiErr.ErrorCode() == "NotFound" || apiErr.ErrorCode() == "NoSuchKey" {
				return false, nil
			}
		}
		return false, err
	}
	return true, nil
}

func (r *R2Provider) DeletePrefix(ctx context.Context, prefix string) error {
	paginator := s3.NewListObjectsV2Paginator(r.client, &s3.ListObjectsV2Input{
		Bucket: aws.String(r.bucket),
		Prefix: aws.String(prefix),
	})

	for paginator.HasMorePages() {
		page, err := paginator.NextPage(ctx)
		if err != nil {
			return fmt.Errorf("listing objects for delete: %w", err)
		}

		if len(page.Contents) == 0 {
			continue
		}

		var objectsToDelete []s3types.ObjectIdentifier
		for _, obj := range page.Contents {
			objectsToDelete = append(objectsToDelete, s3types.ObjectIdentifier{
				Key: obj.Key,
			})
		}

		_, err = r.client.DeleteObjects(ctx, &s3.DeleteObjectsInput{
			Bucket: aws.String(r.bucket),
			Delete: &s3types.Delete{
				Objects: objectsToDelete,
				Quiet:   aws.Bool(true),
			},
		})
		if err != nil {
			return fmt.Errorf("deleting objects under prefix %s: %w", prefix, err)
		}
	}

	return nil
}

func (r *R2Provider) GetPublicURL(key string) string {
	return r.publicURL + "/" + key
}


func isPublicKey(key string) bool {
	return strings.HasPrefix(key, "product-images/") || strings.HasPrefix(key, "profile-images/") || strings.HasPrefix(key, "products/images/")
}

// EnsureBucketExists checks if the bucket exists and creates it with a public read policy if it doesn't.
// This is primarily used for local development with MinIO.
func (r *R2Provider) EnsureBucketExists(ctx context.Context) error {
	_, err := r.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(r.bucket),
	})
	if err == nil {
		return nil
	}

	// Try to create the bucket
	_, err = r.client.CreateBucket(ctx, &s3.CreateBucketInput{
		Bucket: aws.String(r.bucket),
	})
	if err != nil {
		var apiErr smithy.APIError
		if errors.As(err, &apiErr) {
			code := apiErr.ErrorCode()
			if code == "BucketAlreadyExists" || code == "BucketAlreadyOwnedByYou" {
				// Already exists, we can proceed
			} else {
				return fmt.Errorf("creating bucket: %w", err)
			}
		} else {
			return fmt.Errorf("creating bucket: %w", err)
		}
	}

	// Set public read policy
	policy := `{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":["*"]},"Action":["s3:GetObject"],"Resource":["arn:aws:s3:::` + r.bucket + `/*"]}]}`
	_, err = r.client.PutBucketPolicy(ctx, &s3.PutBucketPolicyInput{
		Bucket: aws.String(r.bucket),
		Policy: aws.String(policy),
	})
	if err != nil {
		return fmt.Errorf("setting bucket policy: %w", err)
	}

	return nil
}

