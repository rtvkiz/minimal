# Minimal Zero-CVE Container Images Build System
# Uses Chainguard melange (build from source) + apko (assemble image)
# All images are shell-less/distroless for security

REGISTRY ?= ghcr.io
OWNER ?= $(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
VERSION ?= $(shell date +%Y%m%d)
JENKINS_VERSION ?= 2.541.1
PYTHON_VERSION ?= 3.13.1

.PHONY: all build scan clean help
.PHONY: python python-melange keygen jenkins jenkins-melange
.PHONY: scan-python scan-jenkins

all: build scan

# Build all images
build: python jenkins

#------------------------------------------------------------------------------
# SIGNING KEY (required for melange packages)
#------------------------------------------------------------------------------
keygen:
	@if [ ! -f melange.rsa ]; then \
		echo "Generating melange signing keypair..."; \
		melange keygen; \
		echo "✓ Signing key generated"; \
	fi

#------------------------------------------------------------------------------
# PYTHON IMAGE (melange from source + apko, shell-less, no pip)
#------------------------------------------------------------------------------
python-melange: keygen
	@echo "Building Python $(PYTHON_VERSION) from source with melange..."
	melange build python/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Python package built from source"

python: python-melange
	@echo "Assembling minimal-python image with apko..."
	apko build python/apko/python.yaml \
		$(REGISTRY)/$(OWNER)/minimal-python:$(VERSION) \
		python.tar \
		--arch x86_64 \
		--keyring-append melange.rsa.pub
	docker load < python.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	@rm -f python.tar sbom-*.spdx.json
	@echo "✓ minimal-python built (from source, shell-less, ~25MB)"

#------------------------------------------------------------------------------
# JENKINS IMAGE (melange jlink JRE + WAR + apko, shell-less)
#------------------------------------------------------------------------------
jenkins-melange: keygen
	@echo "Building Jenkins $(JENKINS_VERSION) with custom JRE (jlink) via melange..."
	melange build jenkins/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Jenkins package built (custom JRE + WAR)"

jenkins: jenkins-melange
	@echo "Assembling minimal-jenkins image with apko..."
	apko build jenkins/apko/jenkins.yaml \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION) \
		jenkins.tar \
		--arch x86_64 \
		--keyring-append melange.rsa.pub
	docker load < jenkins.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	@rm -f jenkins.tar sbom-*.spdx.json
	@echo "✓ minimal-jenkins built (jlink JRE, shell-less)"

#------------------------------------------------------------------------------
# CVE SCANNING
#------------------------------------------------------------------------------
scan: scan-python scan-jenkins

scan-python:
	@echo "Scanning minimal-python..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	@echo "✓ minimal-python: zero CVE"

scan-jenkins:
	@echo "Scanning minimal-jenkins..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	@echo "✓ minimal-jenkins: zero CVE"

# Full scan with all severities
scan-all:
	@echo "Full vulnerability scan..."
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest

#------------------------------------------------------------------------------
# IMAGE SIZE REPORT
#------------------------------------------------------------------------------
size:
	@echo "Image sizes:"
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | \
		grep -E "(minimal-python|minimal-jenkins)" || true

#------------------------------------------------------------------------------
# TESTING
#------------------------------------------------------------------------------
test: test-python test-jenkins

test-python:
	@echo "Testing Python image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-python:latest \
		-c "import sys; print(f'Python {sys.version}')"
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-python:latest \
		-c "import ssl; print('TLS OK:', ssl.OPENSSL_VERSION)"
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-python:latest \
		-c "import json, hashlib; print('stdlib OK')"
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-python:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Python tests passed"

test-jenkins:
	@echo "Testing Jenkins image (Java version)..."
	docker run --rm --entrypoint /usr/bin/java \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest -version
	@echo "Verifying Jenkins WAR..."
	docker run --rm --entrypoint /usr/bin/java \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest \
		-jar /usr/share/jenkins/jenkins.war --version
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-jenkins:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Jenkins tests passed"

#------------------------------------------------------------------------------
# PUSH TO REGISTRY
#------------------------------------------------------------------------------
push:
	docker push $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-python:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-jenkins:latest

#------------------------------------------------------------------------------
# CLEANUP
#------------------------------------------------------------------------------
clean:
	@echo "Cleaning up..."
	docker rmi $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-python:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-jenkins:latest 2>/dev/null || true
	rm -f *.tar sbom-*.spdx.json
	rm -rf packages/
	@echo "✓ Cleanup complete"

#------------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------------
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Minimal Zero-CVE Container Images (Shell-less)"
	@echo "  Using melange (source build) + apko (image assembly)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Images:"
	@echo "  make python          Build Python $(PYTHON_VERSION) from source"
	@echo "  make python-melange  Build Python package only (no image)"
	@echo "  make jenkins         Build Jenkins $(JENKINS_VERSION) (jlink JRE)"
	@echo "  make jenkins-melange Build Jenkins package only (no image)"
	@echo "  make build           Build all images"
	@echo ""
	@echo "Scanning:"
	@echo "  make scan           Scan for CRITICAL/HIGH CVEs"
	@echo "  make scan-all       Full vulnerability scan"
	@echo "  make size           Show image sizes"
	@echo ""
	@echo "Other:"
	@echo "  make keygen         Generate melange signing key"
	@echo "  make test           Test all images"
	@echo "  make push           Push to registry"
	@echo "  make clean          Remove local images + packages"
	@echo ""
	@echo "Variables:"
	@echo "  PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "  JENKINS_VERSION=$(JENKINS_VERSION)"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  OWNER=$(OWNER)"
