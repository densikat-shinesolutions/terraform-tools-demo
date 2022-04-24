package test

import (
	"encoding/json"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestService(t *testing.T) {

	serviceEnvironment := strings.ToLower(random.UniqueId())
	awsRegion := "ap-southeast-2"

	// Construct the terraform options with default retryable errors to handle the most common
	// retryable errors in terraform testing.
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Set the path to the Terraform code that will be tested.
		TerraformDir: "../application_v6",
		Vars: map[string]interface{}{
			"environment": serviceEnvironment,
			"vpc_name": "terraform-tools-demo-dev",
			"subnet_name": "terraform-tools-demo-dev-subnet",
			"stack_name": "terraform-tools-demo",
			"aws_region": awsRegion,
		},
	})

	// Clean up resources with "terraform destroy" at the end of the test.
	defer terraform.Destroy(t, terraformOptions)

	// Run "terraform init" and "terraform apply". Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)

	// Empty and cleanup bucket
	s3Bucket := terraform.Output(t, terraformOptions, "service_bucket")
	defer aws.EmptyS3Bucket(t, awsRegion, s3Bucket)

	publicIp := terraform.Output(t, terraformOptions, "instance_public_ip")
	url := fmt.Sprintf("http://%s:8080/images", publicIp)
	testBody := "{\"FileName\": \"test.png\",\"Description\": \"This is my test image\"}"

	// Post image metadata to service
	http_helper.HTTPDoWithRetry(t, "POST", url, []byte(testBody), map[string]string{"Content-Type": "application/json"}, 200, 30, 5*time.Second, nil)

	// Get our image metadata
	_, body := http_helper.HttpGet(t, url, nil)

	// Parse our body into a map
	var mp []map[string]interface{}

	err := json.Unmarshal([]byte(body), &mp)

	if (err != nil) {
		t.Logf("Error unmarshalling JSON response: %s", err.Error())
		t.FailNow()
	}

	// Get number of elements in our JSON array response
	numElements := len(mp)
	if (numElements != 1) {
		t.Logf("Expected 1 element returned, got: %d", numElements)
		t.FailNow()
	}

	// Make sure the values coming back in the response are correct
	fileName := mp[0]["FileName"]
	description := mp[0]["Description"]

	assert.Equal(t, "test.png", fileName)
	assert.Equal(t, "This is my test image", description)

	// Check the instance has write access to the bucket
	_, err = aws.GetS3ObjectContentsE(t, awsRegion, s3Bucket, "application/dbcreated.flag")
	if (err != nil) {
		t.Logf("Error checking for object in S3: %s", err.Error())
		t.FailNow()
	}
}
