#!/bin/bash

# Complete Helm-based deployment for Velero + Victoria Logs backup with EKS Pod Identity

# Variables - UPDATE THESE
AWS_REGION="us-west-2"
BUCKET_NAME="backupbucket"
VICTORIA_LOGS_NAMESPACE="default"
AWS_ACCOUNT_ID="123456789012"  # Your AWS account ID
CLUSTER_NAME="your-eks-cluster"
ROLE_NAME="VeleroRole"

echo "=== Step 1: Setup EKS Pod Identity (run once) ==="
echo "Run the EKS Pod Identity setup script first if not already done"
echo ""

echo "=== Step 2: Install Velero via Helm ==="

# Add Velero Helm repository
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update

# Create velero namespace
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

# Install Velero with EKS Pod Identity configuration
helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --values velero-values.yaml \
  --set configuration.backupStorageLocation[0].config.region=${AWS_REGION} \
  --set configuration.backupStorageLocation[0].bucket=${BUCKET_NAME} \
  --set schedules.victoria-logs-daily.template.includedNamespaces[0]=${VICTORIA_LOGS_NAMESPACE} \
  --set serviceAccount.server.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}" \
  --set credentials.useSecret=false \
  --wait --timeout=10m

echo "=== Step 3: Verify Velero Installation ==="
kubectl get pods -n velero
kubectl get backupstoragelocations -n velero

echo "=== Step 4: Verify EKS Pod Identity ==="
echo "Checking if Velero pod has the correct IAM role..."
kubectl describe pod -n velero -l app.kubernetes.io/name=velero | grep -E "AWS_ROLE_ARN|AWS_WEB_IDENTITY_TOKEN" || echo "Pod Identity environment variables not found - check association"

echo "=== Step 5: Label Victoria Logs PVCs ==="
# Get PVCs in Victoria Logs namespace and label them
echo "Available PVCs in ${VICTORIA_LOGS_NAMESPACE}:"
kubectl get pvc -n ${VICTORIA_LOGS_NAMESPACE}

echo ""
echo "Please run these commands to label your specific PVCs:"
echo "kubectl label pvc <your-pvc-1> -n ${VICTORIA_LOGS_NAMESPACE} velero.io/backup=enabled"
echo "kubectl label pvc <your-pvc-2> -n ${VICTORIA_LOGS_NAMESPACE} velero.io/backup=enabled"
echo "kubectl label pvc <your-pvc-3> -n ${VICTORIA_LOGS_NAMESPACE} velero.io/backup=enabled"

echo "=== Step 4: Optional - Deploy Custom Backup Chart ==="
echo "If you created the custom backup chart, deploy it with:"
echo "helm upgrade --install victoria-logs-backup ./victoria-logs-backup \\"
echo "  --set backup.targetNamespace=${VICTORIA_LOGS_NAMESPACE} \\"
echo "  --set pvcNames[0]=your-pvc-1 \\"
echo "  --set pvcNames[1]=your-pvc-2 \\"
echo "  --set pvcNames[2]=your-pvc-3"

echo "=== Step 5: Test Manual Backup ==="
echo "Create a manual backup to test:"
echo "velero backup create test-victoria-logs-backup \\"
echo "  --include-resources persistentvolumeclaims,pods,deployments,statefulsets,services,configmaps,secrets \\"
echo "  --include-namespaces ${VICTORIA_LOGS_NAMESPACE} \\"
echo "  --selector 'velero.io/backup=enabled' \\"
echo "  --snapshot-volumes=false \\"
echo "  --default-volumes-to-fs-backup=true"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Label your PVCs as shown above"
echo "2. Test the backup process"
echo "3. Monitor backup status with: velero backup get"
echo "4. Check backup details with: velero backup describe <backup-name>"

echo ""
echo "For restore:"
echo "velero restore create test-restore --from-backup <backup-name>"
