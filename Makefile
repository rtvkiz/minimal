REGISTRY ?= ghcr.io
OWNER ?= $(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
VERSION ?= $(shell date +%Y%m%d)

IMAGES = busybox alpine nginx python jenkins

.PHONY: all build scan push clean $(IMAGES)

all: build scan

build: $(IMAGES)

$(IMAGES):
	docker build -t $(REGISTRY)/$(OWNER)/minimal-$@:$(VERSION) \
		-t $(REGISTRY)/$(OWNER)/minimal-$@:latest \
		./$@

scan:
	@for img in $(IMAGES); do \
		echo "Scanning minimal-$$img..."; \
		trivy image --exit-code 1 --severity CRITICAL,HIGH \
			$(REGISTRY)/$(OWNER)/minimal-$$img:$(VERSION); \
	done

scan-%:
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-$*:$(VERSION)

push:
	@for img in $(IMAGES); do \
		docker push $(REGISTRY)/$(OWNER)/minimal-$$img:$(VERSION); \
		docker push $(REGISTRY)/$(OWNER)/minimal-$$img:latest; \
	done

clean:
	@for img in $(IMAGES); do \
		docker rmi $(REGISTRY)/$(OWNER)/minimal-$$img:$(VERSION) 2>/dev/null || true; \
		docker rmi $(REGISTRY)/$(OWNER)/minimal-$$img:latest 2>/dev/null || true; \
	done
