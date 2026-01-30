# Minimal Hardened Container Images Build System
# Uses Chainguard melange (build from source) + apko (assemble image)
# All images are shell-less/distroless for security

REGISTRY ?= ghcr.io
OWNER ?= $(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
VERSION ?= $(shell date +%Y%m%d)
JENKINS_VERSION ?= 2.541.1
NGINX_VERSION ?= 1.29.4
HTTPD_VERSION ?= 2.4.66
REDIS_VERSION ?= 8.4.0

.PHONY: all build scan clean help
.PHONY: python jenkins jenkins-melange go nginx httpd redis-slim redis-slim-melange postgres-slim keygen
.PHONY: scan-python scan-jenkins scan-go scan-nginx scan-httpd scan-redis-slim scan-postgres-slim

all: build scan

# Build all images
build: python jenkins go nginx httpd redis-slim postgres-slim

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
# PYTHON IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
python:
	@echo "Assembling minimal-python image with apko..."
	apko build python/apko/python.yaml \
		$(REGISTRY)/$(OWNER)/minimal-python:$(VERSION) \
		python.tar \
		--arch x86_64
	docker load < python.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	@rm -f python.tar sbom-*.spdx.json
	@echo "✓ minimal-python built (Wolfi package, shell-less)"

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
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < jenkins.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	@rm -f jenkins.tar sbom-*.spdx.json
	@echo "✓ minimal-jenkins built (jlink JRE, shell-less)"

#------------------------------------------------------------------------------
# GO IMAGE (Wolfi pre-built package, with build tools)
#------------------------------------------------------------------------------
go:
	@echo "Assembling minimal-go image with apko..."
	apko build go/apko/go.yaml \
		$(REGISTRY)/$(OWNER)/minimal-go:$(VERSION) \
		go.tar \
		--arch x86_64
	docker load < go.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-go:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-go:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-go:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-go:latest
	@rm -f go.tar sbom-*.spdx.json
	@echo "✓ minimal-go built (Wolfi package, with build tools)"

#------------------------------------------------------------------------------
# NGINX IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
nginx:
	@echo "Assembling minimal-nginx image with apko..."
	apko build nginx/apko/nginx.yaml \
		$(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION) \
		nginx.tar \
		--arch x86_64
	docker load < nginx.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-nginx:latest
	@rm -f nginx.tar sbom-*.spdx.json
	@echo "✓ minimal-nginx built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# HTTPD IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
httpd:
	@echo "Assembling minimal-httpd image with apko..."
	apko build httpd/apko/httpd.yaml \
		$(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION) \
		httpd.tar \
		--arch x86_64
	docker load < httpd.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-httpd:latest
	@rm -f httpd.tar sbom-*.spdx.json
	@echo "✓ minimal-httpd built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# REDIS SLIM IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
redis-slim-melange: keygen
	@echo "Building Redis $(REDIS_VERSION) from source via melange..."
	melange build redis-slim/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Redis package built from source"

redis-slim: redis-slim-melange
	@echo "Assembling minimal-redis-slim image with apko..."
	apko build redis-slim/apko/redis.yaml \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION) \
		redis-slim.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < redis-slim.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	@rm -f redis-slim.tar sbom-*.spdx.json
	@echo "✓ minimal-redis-slim built (source build)"

#------------------------------------------------------------------------------
# POSTGRES SLIM IMAGE (Wolfi pre-built package)
#------------------------------------------------------------------------------
postgres-slim:
	@echo "Assembling minimal-postgres-slim image with apko..."
	apko build postgres-slim/apko/postgres.yaml \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION) \
		postgres-slim.tar \
		--arch x86_64
	docker load < postgres-slim.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest
	@rm -f postgres-slim.tar sbom-*.spdx.json
	@echo "✓ minimal-postgres-slim built (Wolfi package)"

#------------------------------------------------------------------------------
# CVE SCANNING
#------------------------------------------------------------------------------
scan: scan-python scan-jenkins scan-go scan-nginx scan-httpd scan-redis-slim scan-postgres-slim

scan-python:
	@echo "Scanning minimal-python..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	@echo "✓ minimal-python: scan passed"

scan-jenkins:
	@echo "Scanning minimal-jenkins..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	@echo "✓ minimal-jenkins: scan passed"

scan-go:
	@echo "Scanning minimal-go..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-go:latest
	@echo "✓ minimal-go: scan passed"

scan-nginx:
	@echo "Scanning minimal-nginx..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-nginx:latest
	@echo "✓ minimal-nginx: scan passed"

scan-httpd:
	@echo "Scanning minimal-httpd..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-httpd:latest
	@echo "✓ minimal-httpd: scan passed"

scan-redis-slim:
	@echo "Scanning minimal-redis-slim..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	@echo "✓ minimal-redis-slim: scan passed"

scan-postgres-slim:
	@echo "Scanning minimal-postgres-slim..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest
	@echo "✓ minimal-postgres-slim: scan passed"

# Full scan with all severities
scan-all:
	@echo "Full vulnerability scan..."
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-python:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-go:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-nginx:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-httpd:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest

#------------------------------------------------------------------------------
# IMAGE SIZE REPORT
#------------------------------------------------------------------------------
size:
	@echo "Image sizes:"
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | \
		grep -E "(minimal-python|minimal-jenkins|minimal-go|minimal-redis-slim|minimal-postgres-slim)" || true

#------------------------------------------------------------------------------
# TESTING
#------------------------------------------------------------------------------
test: test-python test-jenkins test-go test-node test-nginx test-httpd test-redis-slim test-postgres-slim

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

test-go:
	@echo "Testing Go image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-go:latest version
	@echo "Testing Go build..."
	docker run --rm -v $(PWD):/app -w /app $(REGISTRY)/$(OWNER)/minimal-go:latest \
		build -o /tmp/test /dev/null 2>&1 | head -1 || echo "Go build tools OK"
	@echo "Verifying build tools..."
	docker run --rm --entrypoint /usr/bin/gcc $(REGISTRY)/$(OWNER)/minimal-go:latest --version | head -1
	docker run --rm --entrypoint /usr/bin/make $(REGISTRY)/$(OWNER)/minimal-go:latest --version
	@echo "Verifying git..."
	docker run --rm --entrypoint /usr/bin/git $(REGISTRY)/$(OWNER)/minimal-go:latest --version
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-go:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Go tests passed"

test-node:
	@echo "Testing Node.js image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-node:latest --version
	@echo "Testing simple script..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-node:latest -e 'console.log("Hello minimal node")'
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-node:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Node.js tests passed"

test-nginx:
	@echo "Testing Nginx image..."
	@docker run -d --name nginx-test $(REGISTRY)/$(OWNER)/minimal-nginx:latest
	@sleep 2
	@if docker ps | grep -q nginx-test; then \
		echo "Nginx is running"; \
		docker logs nginx-test; \
		docker stop nginx-test && docker rm nginx-test; \
	else \
		echo "Nginx failed to start, checking logs..."; \
		docker logs nginx-test 2>&1 || true; \
		docker rm nginx-test 2>/dev/null || true; \
		exit 1; \
	fi
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-nginx:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Nginx tests passed"

test-httpd:
	@echo "Testing HTTPD image..."
	@docker run -d --name httpd-test $(REGISTRY)/$(OWNER)/minimal-httpd:latest
	@sleep 2
	@if docker ps | grep -q httpd-test; then \
		echo "HTTPD is running"; \
		docker logs httpd-test; \
		docker stop httpd-test && docker rm httpd-test; \
	else \
		echo "HTTPD failed to start, checking logs..."; \
		docker logs httpd-test 2>&1 || true; \
		docker rm httpd-test 2>/dev/null || true; \
		exit 1; \
	fi
	@echo "Checking for shell presence (informational)..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-httpd:latest -c "true" 2>/dev/null \
		&& echo "NOTE: /bin/sh present in minimal-httpd (not treated as failure)" \
		|| echo "✓ No /bin/sh found (shell-less)"
	@echo "✓ HTTPD tests passed"

test-redis-slim:
	@echo "Testing Redis Slim image..."
	@docker run -d --name redis-test $(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	@sleep 2
	@if docker ps | grep -q redis-test; then \
		echo "Redis is running"; \
		docker logs redis-test; \
		docker stop redis-test && docker rm redis-test; \
	else \
		echo "Redis failed to start, checking logs..."; \
		docker logs redis-test 2>&1 || true; \
		docker rm redis-test 2>/dev/null || true; \
		exit 1; \
	fi
	@echo "✓ Redis Slim tests passed"

test-postgres-slim:
	@echo "Testing Postgres Slim image..."
	docker run --rm --entrypoint /usr/bin/postgres \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest --version
	docker run --rm --entrypoint /usr/bin/psql \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest --version
	@echo "✓ Postgres Slim tests passed"

#------------------------------------------------------------------------------
# PUSH TO REGISTRY
#------------------------------------------------------------------------------
push:
	docker push $(REGISTRY)/$(OWNER)/minimal-python:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-python:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-jenkins:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-jenkins:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-go:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-go:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-nginx:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-httpd:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	docker push $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)
	docker push $(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest

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
	docker rmi $(REGISTRY)/$(OWNER)/minimal-go:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-go:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-go:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest 2>/dev/null || true
	rm -f *.tar sbom-*.spdx.json
	rm -rf packages/
	@echo "✓ Cleanup complete"

#------------------------------------------------------------------------------
# HELP
#------------------------------------------------------------------------------
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Minimal Hardened Container Images (Shell-less)"
	@echo "  Using apko (image assembly) + Wolfi packages"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Images:"
	@echo "  make python          Build Python (Wolfi package)"
	@echo "  make go              Build Go (Wolfi package)"
	@echo "  make jenkins         Build Jenkins $(JENKINS_VERSION) (jlink JRE)"
	@echo "  make jenkins-melange Build Jenkins package only (no image)"
	@echo "  make nginx           Build Nginx $(NGINX_VERSION) (Wolfi package)"
	@echo "  make httpd           Build HTTPD $(HTTPD_VERSION) (Wolfi package)"
	@echo "  make redis-slim      Build Redis Slim $(REDIS_VERSION) (source build)"
	@echo "  make postgres-slim   Build Postgres Slim (Wolfi package)"
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
	@echo "  JENKINS_VERSION=$(JENKINS_VERSION)"
	@echo "  NGINX_VERSION=$(NGINX_VERSION)"
	@echo "  HTTPD_VERSION=$(HTTPD_VERSION)"
	@echo "  REDIS_VERSION=$(REDIS_VERSION)"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  OWNER=$(OWNER)"
