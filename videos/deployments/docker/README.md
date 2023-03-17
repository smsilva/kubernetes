# Docker

## Build

```bash
docker build -t nginx-blue:1.23.3-alpine ./blue

docker build -t nginx-green:1.23.3-alpine ./green

docker run \
  --detach \
  --publish 8000:80 \
  --name nginx-blue \
  nginx-blue:1.23.3-alpine

docker run \
  --detach \
  --publish 8001:80 \
  --name nginx-green \
  nginx-green:1.23.3-alpine

docker ps

curl -i localhost:8000/data.json

curl -i localhost:8001/data.json

docker kill nginx-blue nginx-green
```
