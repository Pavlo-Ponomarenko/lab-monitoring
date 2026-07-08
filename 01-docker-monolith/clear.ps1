docker rm -f mon web web-exp
docker network rm monlab
docker rmi monitoring-monolith:dev
docker image prune -f