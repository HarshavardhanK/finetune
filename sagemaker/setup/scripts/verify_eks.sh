aws eks update-kubeconfig --name $EKS_CLUSTER_NAME
kubectl config current-context 
kubectl get svc

#verify
helm list -n kube-system
