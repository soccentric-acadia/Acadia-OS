IMAGE_NAME  ?= rpi5-kas
IMAGE_TAG   ?= latest
KAS_VERSION ?= 4.5

.PHONY: all build clean

all: build

## Build the Docker image that contains KAS + extra tooling
build:
	docker build --build-arg KAS_VERSION=$(KAS_VERSION) -t $(IMAGE_NAME):$(IMAGE_TAG) .

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
