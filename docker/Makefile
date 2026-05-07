IMAGE_NAME ?= rpi5-kas
IMAGE_TAG  ?= latest

.PHONY: all build clean

all: build

## Build the Docker image that contains KAS + extra tooling
build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
