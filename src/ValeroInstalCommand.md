#!/bin/bash

# Velero Helm Installation for ST1 Volumes

# Variables - UPDATE THESE
AWS_REGION="us-west-2"
BUCKET_NAME="backupbucket"
NAMESPACE="velero"
VICTORIA_LOGS_NAMESPACE="default"  # Replace with your Victoria Logs namespace

#!/bin/bash

# Velero Helm Installation with EKS Pod Identity

# Variables - UPDATE THESE
AWS_REGION="us-west-2"
BUCKET_NAME="backupbucket"
NAMESPACE="velero"
VICTORIA_LOGS_NAMESPACE="default"  # Replace with your Victoria Logs namespace
AWS_ACCOUNT_ID="123456789012"  # Your AWS account ID
ROLE_NAME="VeleroRole"

echo "Installing Velero with EKS Pod Identity..."

# Create namespace
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Add Velero Helm repository
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# Install Velero with EKS Pod Identity
helm install velero vmware-tanzu/velero \
  --namespace ${NAMESPACE} \
  --values velero-values.yaml \
  --set configuration.backupStorageLocation[0].config.region=${AWS_REGION} \
  --set configuration.backupStorageLocation[0].bucket=${BUCKET_NAME} \
  --set schedules.victoria-logs-daily.template.includedNamespaces[0]=${VICTORIA_LOGS_NAMESPACE} \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
  --set credentials.useSecret=false

echo "Waiting for Velero to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/velero -n ${NAMESPACE}

echo "Checking Velero installation..."
kubectl get pods -n ${NAMESPACE}

echo "Checking node-agent (required for ST1 file-system backups)..."
kubectl get pods -n ${NAMESPACE} -l name=node-agent

echo "Verifying EKS Pod Identity..."
kubectl describe pod -n ${NAMESPACE} -l app.kubernetes.io/name=velero | grep -A5 -B5 "AWS_ROLE_ARN\|AWS_WEB_IDENTITY_TOKEN"

echo ""
echo "Velero installation complete!"
echo ""
echo "Next steps:"
echo "1. Label your Victoria Logs PVCs: kubectl label pvc <pvc-name> -n ${VICTORIA_LOGS_NAMESPACE} velero.io/backup=enabled"
echo "2. Test backup: helm test velero -n ${NAMESPACE}"
echo "3. Create manual backup: velero backup create test-backup --selector velero.io/backup=enabled"
