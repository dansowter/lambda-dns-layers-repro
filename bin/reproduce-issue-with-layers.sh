#!/usr/bin/env bash

set -euo pipefail

COSMOS_ROOT=$(git rev-parse --show-toplevel)

LambdaTrustPolicy=$(tempfile)
cp serverless.with-layers.yml serverless.yml
trap 'rm ${LambdaTrustPolicy} serverless.yml' EXIT

unset AWS_PROFILE
export AWS_ACCESS_KEY_ID="FAKE_AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="FAKE_AWS_SECRET_ACCESS_KEY"
export AWS_REGION=us-east-1

EDGE_ENDPOINT_URL=http://localhost:4566

DEV_BUCKET="my-bucket"
PDF_RENDERING_QUEUE="pdfs-to-render"
PDF_RENDERING_QUEUE_URL="$EDGE_ENDPOINT_URL/queue/pdfs-to-render"
SERVERLESS_BUCKET="serverless-deployments"

echo ""
echo "Setting up S3..."
if aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3api head-bucket --bucket ${DEV_BUCKET} 2>/dev/null; then
    aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3 rb "s3://${DEV_BUCKET}" --force
fi
aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3 mb "s3://${DEV_BUCKET}"

if aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3api head-bucket --bucket ${SERVERLESS_BUCKET} 2>/dev/null; then
    aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3 rb "s3://${SERVERLESS_BUCKET}" --force
fi
aws --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} s3 mb "s3://${SERVERLESS_BUCKET}"

echo ""
echo "Setting up SQS..."
aws sqs delete-queue --queue-url ${PDF_RENDERING_QUEUE_URL} --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} 2>/dev/null || true;
aws sqs create-queue --queue-name ${PDF_RENDERING_QUEUE} --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL}

(cat <<JSONDOC
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSONDOC
) > ${LambdaTrustPolicy}

aws iam create-role --region=${AWS_REGION} --endpoint-url=${EDGE_ENDPOINT_URL} --role-name render-pdfs --assume-role-policy-document file://${LambdaTrustPolicy}

echo ""
echo "Setting up serverless stack..."
npx serverless deploy --stage dev

echo ""
echo "Pushing SQS message to demonstrate issue..."
Destination=$(aws s3 presign --endpoint-url=${EDGE_ENDPOINT_URL} s3://${DEV_BUCKET}/upload.pdf)
Message=$(
(cat <<JSONDOC
{
    "destination": "${Destination}"
}
JSONDOC
) | jq -c
)

aws sqs send-message \
    --queue-url ${PDF_RENDERING_QUEUE_URL} \
    --region=${AWS_REGION} \
    --endpoint-url=${EDGE_ENDPOINT_URL} \
    --message-body=${Message}
