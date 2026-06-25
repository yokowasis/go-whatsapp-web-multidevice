#/bin/bash

docker build -t yokowasis/go-whatsapp-web-multidevice -f docker/golang.Dockerfile .
docker push yokowasis/go-whatsapp-web-multidevice