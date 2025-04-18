#!/bin/bash

# Set up OIDC provider for EKS cluster
eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve

# Install FSx CSI driver
helm repo add aws-fsx-csi-driver https://kubernetes-sigs.github.io/aws-fsx-csi-driver
helm repo update

helm upgrade --install aws-fsx-csi-driver aws-fsx-csi-driver/aws-fsx-csi-driver \
  --namespace kube-system

# Create IAM service account for FSx CSI driver
eksctl create iamserviceaccount \
  --name fsx-csi-controller-sa \
  --override-existing-serviceaccounts \
  --namespace kube-system \
  --cluster $EKS_CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::aws:policy/AmazonFSxFullAccess \
  --approve \
  --role-name AmazonEKSFSxLustreCSIDriverFullAccess \
  --region $AWS_REGION

# Get and annotate service account role ARN
SA_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSFSxLustreCSIDriverFullAccess --query 'Role.Arn' --output text)

kubectl annotate serviceaccount -n kube-system fsx-csi-controller-sa \
  eks.amazonaws.com/role-arn=${SA_ROLE_ARN} --overwrite=true

# Verify service account configuration
kubectl get serviceaccount -n kube-system fsx-csi-controller-sa -oyaml

# Restart CSI controller deployment
kubectl rollout restart deployment fsx-csi-controller -n kube-system

# Create StorageClass for FSx
cat <<EOF > storageclass.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: fsx-sc
provisioner: fsx.csi.aws.com
parameters:
  subnetId: $PRIVATE_SUBNET_ID
  securityGroupIds: $SECURITY_GROUP_ID
  deploymentType: PERSISTENT_2
  automaticBackupRetentionDays: "0"
  copyTagsToBackups: "true"
  perUnitStorageThroughput: "250"
  dataCompressionType: "LZ4"
  fileSystemTypeVersion: "2.15"
mountOptions:
  - flock
EOF

kubectl apply -f storageclass.yaml

# Create PersistentVolumeClaim
cat <<EOF > pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: fsx-claim
  namespace: kubeflow
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: fsx-sc
  resources:
    requests:
      storage: 1200Gi
EOF

kubectl apply -f pvc.yaml

# Verify PVC status
kubectl describe pvc fsx-claim -n kubeflow

# Create test pod to mount the volume
cat <<EOF > pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: fsx-app
  namespace: kubeflow
spec:
  containers:
  - name: app
    image: ubuntu
    command: ["/bin/sh"]
    args: ["-c", "while true; do echo \$(date -u) >> /data/out.txt; sleep 5; done"]
    volumeMounts:
    - name: persistent-storage
      mountPath: /data
  volumes:
  - name: persistent-storage
    persistentVolumeClaim:
      claimName: fsx-claim
EOF

kubectl apply -f pod.yaml

# Verify pod status
kubectl get pods -n kubeflow
kubectl get pods -n A

# Access the pod's shell for debugging
kubectl exec -it fsx-app -n kubeflow -- /bin/sh