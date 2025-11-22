# Registry configuration
# Override these via environment variables if you want to use your own registry
REGISTRY_ADDRESS := ghcr.io
IMAGE_NAME := queeq/android-builder
IMAGE_TAG := latest

# Kubernetes configuration
NAME := android-build
NAMESPACE := $(NAME)

# Download configuration
DOWNLOAD_DIR ?= $(CURDIR)/download
LOCAL_PORT ?= 2222


.PHONY: all image clean login build push template install uninstall start-build watch-build debug download config
all: install
image: clean login build push

clean:
	docker image prune -af

login:
	docker login $(REGISTRY_ADDRESS)

build:
	docker build --platform linux/amd64 -t $(REGISTRY_ADDRESS)/$(IMAGE_NAME):$(IMAGE_TAG) docker/

push:
	docker push $(REGISTRY_ADDRESS)/$(IMAGE_NAME):$(IMAGE_TAG)
	@echo ""
	@echo "Image pushed successfully!"
	@echo "Don't forget to make the package public at:"
	@echo "https://github.com/$(shell echo $(IMAGE_NAME) | cut -d/ -f1)?tab=packages"

template:
	helm template $(NAME) -n $(NAMESPACE) --create-namespace . > template.yaml

install:
	@if [ ! -f build.env ]; then \
		echo "Error: build.env not found. Run 'make config' first."; \
		exit 1; \
	fi
	@echo "Deploying with configuration from build.env..."
	helm upgrade -i -n $(NAMESPACE) --create-namespace \
		--set image.repository=$(REGISTRY_ADDRESS)/$(IMAGE_NAME) \
		--set image.tag=$(IMAGE_TAG) \
		$(NAME) .
	$(MAKE) watch-build

uninstall:
	helm uninstall -n $(NAMESPACE) $(NAME)

watch-build:
	@echo "Waiting for build pod to be ready..."
	@kubectl wait --for=condition=ready pod -l app=$(NAME) -n $(NAMESPACE) --timeout=300s
	@if [ $$? -eq 0 ]; then \
		echo "Build pod is ready, following logs..."; \
		kubectl logs -f -l app=$(NAME) -c build -n $(NAMESPACE); \
	else \
		echo "Error: Build pod failed to become ready"; \
		exit 1; \
	fi
	@echo "Waiting for job completion..."
	@kubectl wait --for=condition=complete job -l app=$(NAME) -n $(NAMESPACE) --timeout=86400s
	@if [ $$? -eq 0 ]; then \
		echo "Build completed successfully!"; \
	else \
		echo "Build failed or timed out"; \
		exit 1; \
	fi

debug:
	@echo "Creating debug pod..."
	@kubectl apply -f debug-pod.yaml -n $(NAMESPACE)
	@echo "Waiting for debug pod to be ready..."
	@kubectl wait --for=condition=ready pod -l app=debug-shell -n $(NAMESPACE) --timeout=60s
	@if [ $$? -eq 0 ]; then \
		echo "Debug pod is ready, starting shell..."; \
		trap 'kubectl delete pod debug-shell -n $(NAMESPACE)' EXIT; \
		kubectl exec -it debug-shell -n $(NAMESPACE) -- bash -c "apt update && DEBIAN_FRONTEND=noninteractive apt install -y vim less && bash"; \
	else \
		echo "Error: Debug pod failed to become ready"; \
		kubectl delete pod debug-shell -n $(NAMESPACE) --ignore-not-found; \
		exit 1; \
	fi

download:
	@NAMESPACE=$(NAMESPACE) APP=$(NAME) DOWNLOAD_DIR=$(DOWNLOAD_DIR) LOCAL_PORT=$(LOCAL_PORT) ./download.sh

config:
	@if [ -f build.env ]; then \
		echo "build.env already exists. Remove it first if you want to recreate it."; \
		exit 1; \
	fi
	@cp build.env.example build.env
	@echo "Created build.env from build.env.example"
	@echo "Please edit build.env to configure your build settings"
