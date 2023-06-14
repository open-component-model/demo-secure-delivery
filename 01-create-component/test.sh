CLUSTER_NAME=aws-demo
IP=$(docker exec -it $CLUSTER_NAME-control-plane cat /etc/hosts | grep 172.20 | cut -f1)
docker exec -it $CLUSTER_NAME-control-plane sh -c "echo $IP gitea.ocm.dev >> /etc/hosts"
docker exec -it $CLUSTER_NAME-control-plane cat /etc/hosts
