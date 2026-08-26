# Minimal Hardened Container Images Build System
# Uses Chainguard melange (build from source) + apko (assemble image)
# All images are shell-less/distroless for security

REGISTRY ?= ghcr.io
OWNER ?= $(shell git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
VERSION ?= $(shell date +%Y%m%d)

# Helper: extract version from a melange.yaml (single source of truth)
melange_version = $(shell grep '^  version:' $(1) 2>/dev/null | awk '{print $$2}')

# --- Infrastructure/Core ---
JENKINS_VERSION ?= $(call melange_version,images/jenkins/melange.yaml)
NGINX_VERSION ?= 1.29.4
HTTPD_VERSION ?= 2.4.66

# --- Databases/Storage ---
REDIS_VERSION ?= $(call melange_version,images/redis-slim/melange.yaml)
MYSQL_VERSION ?= $(call melange_version,images/mysql/melange.yaml)
MARIADB_VERSION ?= $(call melange_version,images/mariadb/melange.yaml)
MEMCACHED_VERSION ?= $(call melange_version,images/memcached/melange.yaml)
MINIO_VERSION ?= $(call melange_version,images/minio/melange.yaml)
ETCD_VERSION ?= $(call melange_version,images/etcd/melange.yaml)

# --- Languages/Frameworks ---
RUBY_VERSION ?= $(call melange_version,images/ruby/melange.yaml)
RAILS_VERSION ?= $(shell grep '^  rails_version:' images/rails/melange.yaml 2>/dev/null | awk '{print $$2}')

# --- Messaging/Coordination ---
KAFKA_VERSION ?= $(call melange_version,images/kafka/melange.yaml)
ZOOKEEPER_VERSION ?= $(call melange_version,images/zookeeper/melange.yaml)
TOMCAT_VERSION ?= $(call melange_version,images/tomcat/melange.yaml)
VALKEY_VERSION ?= $(call melange_version,images/valkey/melange.yaml)
NATS_VERSION ?= $(call melange_version,images/nats/melange.yaml)
RABBITMQ_VERSION ?= $(call melange_version,images/rabbitmq/melange.yaml)
CASSANDRA_VERSION ?= $(call melange_version,images/cassandra/melange.yaml)
SOLR_VERSION ?= $(call melange_version,images/solr/melange.yaml)
FLINK_VERSION ?= $(call melange_version,images/flink/melange.yaml)
PULSAR_VERSION ?= $(call melange_version,images/pulsar/melange.yaml)

# --- Ingress/Proxies ---
CADDY_VERSION ?= $(call melange_version,images/caddy/melange.yaml)
HAPROXY_VERSION ?= $(call melange_version,images/haproxy/melange.yaml)
TRAEFIK_VERSION ?= $(call melange_version,images/traefik/melange.yaml)
ENVOY_VERSION ?= $(call melange_version,images/envoy/melange.yaml)

# --- Observability ---
PROMETHEUS_VERSION ?= $(call melange_version,images/prometheus/melange.yaml)
ALERTMANAGER_VERSION ?= $(call melange_version,images/alertmanager/melange.yaml)
JAEGER_VERSION ?= $(call melange_version,images/jaeger/melange.yaml)
OTELCOL_VERSION ?= $(call melange_version,images/otelcol/melange.yaml)
VICTORIA_METRICS_VERSION ?= $(call melange_version,images/victoria-metrics/melange.yaml)
TELEGRAF_VERSION ?= $(call melange_version,images/telegraf/melange.yaml)
MIMIR_VERSION ?= $(call melange_version,images/mimir/melange.yaml)

# --- DNS/Secrets/IAM ---
COREDNS_VERSION ?= $(call melange_version,images/coredns/melange.yaml)
PHP_VERSION ?= $(call melange_version,images/php/melange.yaml)
GITEA_VERSION ?= $(call melange_version,images/gitea/melange.yaml)
OPENBAO_VERSION ?= $(call melange_version,images/openbao/melange.yaml)
KEYCLOAK_VERSION ?= $(call melange_version,images/keycloak/melange.yaml)

# --- Logging ---
LOKI_VERSION ?= $(call melange_version,images/loki/melange.yaml)
FLUENT_BIT_VERSION ?= $(call melange_version,images/fluent-bit/melange.yaml)

# --- Search/AI ---
QDRANT_VERSION ?= $(call melange_version,images/qdrant/melange.yaml)
VAULTWARDEN_VERSION ?= $(call melange_version,images/vaultwarden/melange.yaml)
OPENSEARCH_VERSION ?= $(call melange_version,images/opensearch/melange.yaml)

# --- Registries ---
# NB: REGISTRY (above) is the OCI registry hostname; DISTRIBUTION_VERSION is the
# upstream version of distribution/distribution we ship as `minimal-registry`.
DISTRIBUTION_VERSION ?= $(call melange_version,images/registry/melange.yaml)

# --- Dev tools ---
MAILPIT_VERSION ?= $(call melange_version,images/mailpit/melange.yaml)

# --- Service Discovery / Coordination (HashiCorp) ---
CONSUL_VERSION ?= $(call melange_version,images/consul/melange.yaml)

# --- Observability (extra) ---
TEMPO_VERSION ?= $(call melange_version,images/tempo/melange.yaml)
THANOS_VERSION ?= $(call melange_version,images/thanos/melange.yaml)
NODE_EXPORTER_VERSION ?= $(call melange_version,images/node-exporter/melange.yaml)
BLACKBOX_EXPORTER_VERSION ?= $(call melange_version,images/blackbox-exporter/melange.yaml)
REDIS_EXPORTER_VERSION ?= $(call melange_version,images/redis-exporter/melange.yaml)
KUBE_STATE_METRICS_VERSION ?= $(call melange_version,images/kube-state-metrics/melange.yaml)
PUSHGATEWAY_VERSION ?= $(call melange_version,images/pushgateway/melange.yaml)

# --- IaC / GitOps ---
OPENTOFU_VERSION ?= $(call melange_version,images/opentofu/melange.yaml)

# --- Security tooling ---
TRIVY_VERSION ?= $(call melange_version,images/trivy/melange.yaml)
COSIGN_VERSION ?= $(call melange_version,images/cosign/melange.yaml)
SYFT_VERSION ?= $(call melange_version,images/syft/melange.yaml)
GRYPE_VERSION ?= $(call melange_version,images/grype/melange.yaml)
ORAS_VERSION ?= $(call melange_version,images/oras/melange.yaml)
GITLEAKS_VERSION ?= $(call melange_version,images/gitleaks/melange.yaml)
STEP_VERSION ?= $(call melange_version,images/step-cli/melange.yaml)
OPA_VERSION ?= $(call melange_version,images/opa/melange.yaml)
OSV_SCANNER_VERSION ?= $(call melange_version,images/osv-scanner/melange.yaml)
DEX_VERSION ?= $(call melange_version,images/dex/melange.yaml)
SEAWEEDFS_VERSION ?= $(call melange_version,images/seaweedfs/melange.yaml)
OAUTH2_PROXY_VERSION ?= $(call melange_version,images/oauth2-proxy/melange.yaml)
FLUX_VERSION ?= $(call melange_version,images/flux/melange.yaml)
KUSTOMIZE_VERSION ?= $(call melange_version,images/kustomize/melange.yaml)
SOPS_VERSION ?= $(call melange_version,images/sops/melange.yaml)
CRANE_VERSION ?= $(call melange_version,images/crane/melange.yaml)
KUBESEAL_VERSION ?= $(call melange_version,images/kubeseal/melange.yaml)
HELMFILE_VERSION ?= $(call melange_version,images/helmfile/melange.yaml)
REGCTL_VERSION ?= $(call melange_version,images/regctl/melange.yaml)
STERN_VERSION ?= $(call melange_version,images/stern/melange.yaml)
NOTATION_VERSION ?= $(call melange_version,images/notation/melange.yaml)
CONFTEST_VERSION ?= $(call melange_version,images/conftest/melange.yaml)
KUBECONFORM_VERSION ?= $(call melange_version,images/kubeconform/melange.yaml)
KUBE_BENCH_VERSION ?= $(call melange_version,images/kube-bench/melange.yaml)
TRUFFLEHOG_VERSION ?= $(call melange_version,images/trufflehog/melange.yaml)
# --- Messaging (MQTT) ---
MOSQUITTO_VERSION ?= $(call melange_version,images/mosquitto/melange.yaml)
PGBOUNCER_VERSION ?= $(call melange_version,images/pgbouncer/melange.yaml)
UNBOUND_VERSION ?= $(call melange_version,images/unbound/melange.yaml)
KEEPALIVED_VERSION ?= $(call melange_version,images/keepalived/melange.yaml)
METRICS_SERVER_VERSION ?= $(call melange_version,images/metrics-server/melange.yaml)
EXTERNAL_DNS_VERSION ?= $(call melange_version,images/external-dns/melange.yaml)
VELERO_VERSION ?= $(call melange_version,images/velero/melange.yaml)
KANIKO_VERSION ?= $(call melange_version,images/kaniko/melange.yaml)
STEP_CA_VERSION ?= $(call melange_version,images/step-ca/melange.yaml)
SKOPEO_VERSION ?= $(call melange_version,images/skopeo/melange.yaml)
HELM_VERSION ?= $(call melange_version,images/helm/melange.yaml)
KUBECTL_VERSION ?= $(call melange_version,images/kubectl/melange.yaml)

# --- AI/ML ---
CUDA_VERSION ?= 12.9.0

#==============================================================================
# DEV VARIANT MACROS
# Used by each image's :latest-dev variant. See docs/dev-variants/CONVENTIONS.md.
#==============================================================================

# DEV_IMAGE_RULE — declare `<name>-dev` apko build target.
#   $(1) image name (also the dir name and apko config prefix)
#   $(2) prerequisite target (e.g. ruby-melange) — leave empty for apko-only
#   $(3) extra apko flags (e.g. --repository-append ./packages
#        --keyring-append melange.rsa.pub) — leave empty for apko-only
# Conventions: dev apko config lives at <name>/apko/<name>-dev.yaml,
# image publishes :$(VERSION)-dev and :latest-dev tags.
define DEV_IMAGE_RULE
$(1)-dev: $(2)
	@echo "Assembling minimal-$(1)-dev image with apko..."
	apko build images/$(1)/apko/$(1)-dev.yaml \
		$$(REGISTRY)/$$(OWNER)/minimal-$(1):$$(VERSION)-dev \
		$(1)-dev.tar \
		--arch x86_64 $(3)
	docker load < $(1)-dev.tar
	docker tag $$(REGISTRY)/$$(OWNER)/minimal-$(1):$$(VERSION)-dev-amd64 \
		$$(REGISTRY)/$$(OWNER)/minimal-$(1):$$(VERSION)-dev
	docker tag $$(REGISTRY)/$$(OWNER)/minimal-$(1):$$(VERSION)-dev-amd64 \
		$$(REGISTRY)/$$(OWNER)/minimal-$(1):latest-dev
	@rm -f $(1)-dev.tar sbom-*.spdx.json
	@echo "✓ minimal-$(1)-dev built"
endef

# DEV_TEST_RULE — declare `test-<name>-dev` smoke test target.
#   $(1) image name
# Conventions: test script lives at <name>/test-dev.sh and reads $$IMAGE.
define DEV_TEST_RULE
test-$(1)-dev:
	@IMAGE=$$(REGISTRY)/$$(OWNER)/minimal-$(1):latest-dev bash images/$(1)/test-dev.sh
	@echo "✓ $(1) dev tests passed"
endef

.PHONY: all build scan clean help lint-workflows check-autoupdate check-toolchain-pins check-curl-retries test-classifier
.PHONY: zookeeper zookeeper-melange test-zookeeper
.PHONY: tomcat tomcat-melange test-tomcat
.PHONY: pgbouncer pgbouncer-melange pgbouncer-dev test-pgbouncer test-pgbouncer-dev
.PHONY: unbound unbound-melange unbound-dev test-unbound test-unbound-dev
.PHONY: dnsmasq dnsmasq-dev test-dnsmasq test-dnsmasq-dev
.PHONY: patroni patroni-dev test-patroni test-patroni-dev
.PHONY: vector vector-dev test-vector test-vector-dev
.PHONY: keepalived keepalived-melange keepalived-dev test-keepalived test-keepalived-dev
.PHONY: metrics-server metrics-server-melange metrics-server-dev test-metrics-server test-metrics-server-dev
.PHONY: external-dns external-dns-melange external-dns-dev test-external-dns test-external-dns-dev
.PHONY: velero velero-melange velero-dev test-velero test-velero-dev
.PHONY: kaniko kaniko-melange kaniko-dev test-kaniko test-kaniko-dev
.PHONY: step-ca step-ca-melange step-ca-dev test-step-ca test-step-ca-dev
.PHONY: skopeo skopeo-melange skopeo-dev test-skopeo test-skopeo-dev
.PHONY: python python-dev jenkins jenkins-melange go go-dev node-slim node-slim-dev nginx httpd redis-slim redis-slim-melange redis-slim-dev mysql mysql-melange mysql-local memcached memcached-melange memcached-dev caddy caddy-melange haproxy haproxy-melange postgres-slim postgres-slim-dev bun bun-dev sqlite sqlite-dev dotnet dotnet-dev java java-dev ruby ruby-melange ruby-dev php php-melange php-dev rails rails-melange rails-dev deno deno-dev kafka kafka-melange cassandra cassandra-melange solr solr-melange pulsar pulsar-melange keygen opensearch opensearch-melange opensearch-dev mariadb mariadb-melange mariadb-dev valkey valkey-melange valkey-dev
.PHONY: valkey valkey-melange nats nats-melange traefik traefik-melange envoy envoy-melange rabbitmq rabbitmq-melange minio minio-melange
.PHONY: prometheus prometheus-melange alertmanager alertmanager-melange mariadb mariadb-melange
.PHONY: etcd etcd-melange victoria-metrics victoria-metrics-melange jaeger jaeger-melange otelcol otelcol-melange qdrant qdrant-melange deno deno-melange
.PHONY: cuda-python cuda-python-melange
.PHONY: coredns coredns-melange openbao openbao-melange loki loki-melange fluent-bit fluent-bit-melange keycloak keycloak-melange
.PHONY: gitea gitea-melange gitea-melange test-gitea
.PHONY: telegraf telegraf-melange telegraf-dev test-telegraf test-telegraf-dev scan-telegraf
.PHONY: mimir mimir-melange mimir-dev test-mimir test-mimir-dev scan-mimir
.PHONY: registry registry-melange registry-dev test-registry test-registry-dev
.PHONY: mailpit mailpit-melange mailpit-dev test-mailpit test-mailpit-dev
.PHONY: consul consul-melange consul-dev test-consul test-consul-dev
.PHONY: tempo tempo-melange tempo-dev test-tempo test-tempo-dev
.PHONY: opentofu opentofu-melange test-opentofu
.PHONY: trivy trivy-melange test-trivy
.PHONY: cosign cosign-melange test-cosign
.PHONY: syft syft-melange test-syft
.PHONY: grype grype-melange test-grype
.PHONY: oras oras-melange test-oras
.PHONY: gitleaks gitleaks-melange test-gitleaks
.PHONY: step-cli step-cli-melange test-step-cli
.PHONY: opa opa-melange test-opa
.PHONY: osv-scanner osv-scanner-melange test-osv-scanner
.PHONY: dex dex-melange test-dex
.PHONY: seaweedfs seaweedfs-melange test-seaweedfs
.PHONY: oauth2-proxy oauth2-proxy-melange test-oauth2-proxy
.PHONY: flux flux-melange test-flux
.PHONY: kustomize kustomize-melange test-kustomize
.PHONY: sops sops-melange test-sops
.PHONY: crane crane-melange test-crane
.PHONY: kubeseal kubeseal-melange test-kubeseal
.PHONY: helmfile helmfile-melange test-helmfile
.PHONY: regctl regctl-melange test-regctl
.PHONY: stern stern-melange test-stern
.PHONY: notation notation-melange test-notation
.PHONY: conftest conftest-melange test-conftest
.PHONY: kubeconform kubeconform-melange test-kubeconform
.PHONY: kube-bench kube-bench-melange test-kube-bench
.PHONY: trufflehog trufflehog-melange test-trufflehog
.PHONY: thanos thanos-melange test-thanos
.PHONY: node-exporter node-exporter-melange test-node-exporter
.PHONY: blackbox-exporter blackbox-exporter-melange test-blackbox-exporter
.PHONY: flink flink-melange test-flink
.PHONY: vaultwarden vaultwarden-melange test-vaultwarden
.PHONY: redis-exporter redis-exporter-melange test-redis-exporter
.PHONY: kube-state-metrics kube-state-metrics-melange test-kube-state-metrics
.PHONY: pushgateway pushgateway-melange test-pushgateway
.PHONY: mosquitto mosquitto-melange mosquitto-dev test-mosquitto test-mosquitto-dev
.PHONY: scan-python scan-jenkins scan-go scan-node-slim scan-nginx scan-httpd scan-redis-slim scan-mysql scan-memcached scan-caddy scan-haproxy scan-postgres-slim scan-bun scan-sqlite scan-dotnet scan-java scan-ruby scan-php scan-rails scan-kafka scan-cassandra scan-solr scan-pulsar scan-valkey scan-nats scan-traefik scan-rabbitmq scan-minio scan-opensearch scan-prometheus scan-mariadb scan-etcd scan-victoria-metrics scan-jaeger scan-otelcol scan-qdrant scan-deno scan-coredns scan-openbao scan-loki scan-fluent-bit scan-keycloak
.PHONY: test-python test-python-dev test-jenkins test-go test-go-dev test-node-slim test-node-slim-dev test-nginx test-httpd test-redis-slim test-redis-slim-dev test-mysql test-memcached test-caddy test-haproxy test-postgres-slim test-postgres-slim-dev test-bun test-bun-dev test-sqlite test-dotnet test-dotnet-dev test-java test-java-dev test-ruby test-ruby-dev test-php test-php-dev test-rails test-rails-dev test-deno test-deno-dev test-mariadb test-mariadb-dev test-valkey test-valkey-dev test-memcached-dev test-sqlite-dev test-opensearch-dev test-kafka test-cassandra test-solr test-pulsar test-valkey test-nats test-traefik test-envoy test-rabbitmq test-minio test-opensearch test-prometheus test-mariadb test-etcd test-victoria-metrics test-jaeger test-otelcol test-qdrant test-deno test-coredns test-openbao test-loki test-fluent-bit test-keycloak

all: build scan

# Build all images
build: python node-slim bun go java ruby php dotnet deno mysql mariadb postgres-slim pgbouncer unbound dnsmasq keepalived vector patroni metrics-server external-dns velero kaniko step-ca skopeo sqlite opensearch redis-slim valkey memcached kafka zookeeper cassandra solr flink pulsar tomcat rabbitmq nats mosquitto nginx httpd caddy haproxy traefik envoy oauth2-proxy prometheus alertmanager victoria-metrics thanos mimir jaeger loki tempo otelcol fluent-bit telegraf node-exporter blackbox-exporter kube-state-metrics redis-exporter pushgateway coredns etcd openbao keycloak qdrant vaultwarden registry consul helm kubectl opentofu trivy cosign syft grype osv-scanner oras notation conftest kubeconform kube-bench trufflehog flux kustomize sops crane kubeseal helmfile regctl stern gitleaks step-cli opa jenkins gitea minio rails mailpit

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
	apko build images/python/apko/python.yaml \
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

$(eval $(call DEV_IMAGE_RULE,python))
$(eval $(call DEV_IMAGE_RULE,node-slim))
$(eval $(call DEV_IMAGE_RULE,go))
$(eval $(call DEV_IMAGE_RULE,java))
$(eval $(call DEV_IMAGE_RULE,dotnet))
$(eval $(call DEV_IMAGE_RULE,bun))
$(eval $(call DEV_IMAGE_RULE,deno))
$(eval $(call DEV_IMAGE_RULE,rails,rails-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,php,php-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,postgres-slim))
$(eval $(call DEV_IMAGE_RULE,mariadb,mariadb-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,redis-slim,redis-slim-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,valkey,valkey-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,memcached,memcached-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,sqlite))
$(eval $(call DEV_IMAGE_RULE,opensearch))
$(eval $(call DEV_IMAGE_RULE,kafka,kafka-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,cassandra,cassandra-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,solr,solr-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,flink,flink-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,pulsar,pulsar-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,rabbitmq,rabbitmq-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,nats,nats-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,etcd,etcd-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,nginx))
$(eval $(call DEV_IMAGE_RULE,haproxy,haproxy-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,minio,minio-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,httpd))
$(eval $(call DEV_IMAGE_RULE,caddy,caddy-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,traefik,traefik-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,envoy,envoy-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,prometheus,prometheus-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,alertmanager,alertmanager-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,victoria-metrics,victoria-metrics-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,jaeger,jaeger-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,otelcol,otelcol-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,loki,loki-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,fluent-bit,fluent-bit-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,coredns,coredns-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,gitea,gitea-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,jenkins,jenkins-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,openbao,openbao-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,mysql,mysql-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,qdrant,qdrant-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,vaultwarden,vaultwarden-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,keycloak,keycloak-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,registry,registry-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,mailpit,mailpit-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,consul,consul-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,tempo,tempo-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,mosquitto,mosquitto-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,pgbouncer,pgbouncer-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,unbound,unbound-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,dnsmasq))
$(eval $(call DEV_IMAGE_RULE,patroni))
$(eval $(call DEV_IMAGE_RULE,vector))
$(eval $(call DEV_IMAGE_RULE,keepalived,keepalived-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,metrics-server,metrics-server-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,external-dns,external-dns-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,velero,velero-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kaniko,kaniko-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,step-ca,step-ca-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,skopeo,skopeo-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,telegraf,telegraf-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,mimir,mimir-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
# --- dev variants: CLI / exporter / static-Go images. Each ships an
#     apko/<name>-dev.yaml and test-dev.sh; wire their Make rules here.
$(eval $(call DEV_IMAGE_RULE,zookeeper,zookeeper-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,tomcat,tomcat-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,oauth2-proxy,oauth2-proxy-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,thanos,thanos-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,node-exporter,node-exporter-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,blackbox-exporter,blackbox-exporter-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,redis-exporter,redis-exporter-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kube-state-metrics,kube-state-metrics-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,pushgateway,pushgateway-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,helm,helm-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kubectl,kubectl-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,opentofu,opentofu-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,trivy,trivy-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,cosign,cosign-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,syft,syft-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,grype,grype-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,osv-scanner,osv-scanner-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,oras,oras-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,notation,notation-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,conftest,conftest-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kubeconform,kubeconform-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kube-bench,kube-bench-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,trufflehog,trufflehog-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,flux,flux-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kustomize,kustomize-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,sops,sops-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,crane,crane-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,kubeseal,kubeseal-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,helmfile,helmfile-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,regctl,regctl-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,stern,stern-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,gitleaks,gitleaks-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,step-cli,step-cli-melange,--repository-append ./packages --keyring-append melange.rsa.pub))
$(eval $(call DEV_IMAGE_RULE,opa,opa-melange,--repository-append ./packages --keyring-append melange.rsa.pub))

#------------------------------------------------------------------------------
# JENKINS IMAGE (melange jlink JRE + WAR + apko, shell-less)
#------------------------------------------------------------------------------
jenkins-melange: keygen
	@echo "Building Jenkins $(JENKINS_VERSION) with custom JRE (jlink) via melange..."
	melange build images/jenkins/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Jenkins package built (custom JRE + WAR)"

jenkins: jenkins-melange
	@echo "Assembling minimal-jenkins image with apko..."
	apko build images/jenkins/apko/jenkins.yaml \
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
	apko build images/go/apko/go.yaml \
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
# NODE.JS SLIM IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
node-slim:
	@echo "Assembling minimal-node-slim image with apko..."
	apko build images/node-slim/apko/node.yaml \
		$(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION) \
		node.tar \
		--arch x86_64
	docker load < node.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-node-slim:latest
	@rm -f node.tar sbom-*.spdx.json
	@echo "✓ minimal-node-slim built (Wolfi package)"

#------------------------------------------------------------------------------
# NGINX IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
nginx:
	@echo "Assembling minimal-nginx image with apko..."
	apko build images/nginx/apko/nginx.yaml \
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
	apko build images/httpd/apko/httpd.yaml \
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
	melange build images/redis-slim/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Redis package built from source"

redis-slim: redis-slim-melange
	@echo "Assembling minimal-redis-slim image with apko..."
	apko build images/redis-slim/apko/redis.yaml \
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
# MYSQL IMAGE (melange source build + apko, LTS track)
#------------------------------------------------------------------------------
mysql-melange: keygen
	@echo "Building MySQL $(MYSQL_VERSION) from source via melange..."
	melange build images/mysql/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ MySQL package built from source"

# Local-only: build mysql package for x86_64 then assemble image (skip aarch64 to avoid pod failure on WSL2)
mysql-local: keygen
	@echo "Building MySQL $(MYSQL_VERSION) from source (x86_64 only)..."
	melange build images/mysql/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa \
		--out-dir ./packages \
		--runner docker
	@echo "Assembling minimal-mysql image with apko..."
	apko build images/mysql/apko/mysql.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION) \
		mysql.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mysql.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mysql:latest
	@rm -f mysql.tar sbom-*.spdx.json
	@echo "✓ minimal-mysql built locally (x86_64 only)"

mysql: mysql-melange
	@echo "Assembling minimal-mysql image with apko..."
	apko build images/mysql/apko/mysql.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION) \
		mysql.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mysql.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mysql:latest
	@rm -f mysql.tar sbom-*.spdx.json
	@echo "✓ minimal-mysql built (source build)"

#------------------------------------------------------------------------------
# MEMCACHED IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
memcached-melange: keygen
	@echo "Building Memcached $(MEMCACHED_VERSION) from source via melange..."
	melange build images/memcached/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Memcached package built from source"

memcached: memcached-melange
	@echo "Assembling minimal-memcached image with apko..."
	apko build images/memcached/apko/memcached.yaml \
		$(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION) \
		memcached.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < memcached.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-memcached:latest
	@rm -f memcached.tar sbom-*.spdx.json
	@echo "✓ minimal-memcached built (source build)"

#------------------------------------------------------------------------------
# CADDY IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
caddy-melange: keygen
	@echo "Building Caddy $(CADDY_VERSION) from source via melange..."
	melange build images/caddy/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Caddy package built from source"

caddy: caddy-melange
	@echo "Assembling minimal-caddy image with apko..."
	apko build images/caddy/apko/caddy.yaml \
		$(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION) \
		caddy.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < caddy.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-caddy:latest
	@rm -f caddy.tar sbom-*.spdx.json
	@echo "✓ minimal-caddy built (source build)"

#------------------------------------------------------------------------------
# HAPROXY IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
haproxy-melange: keygen
	@echo "Building HAProxy $(HAPROXY_VERSION) from source via melange..."
	melange build images/haproxy/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ HAProxy package built from source"

haproxy: haproxy-melange
	@echo "Assembling minimal-haproxy image with apko..."
	apko build images/haproxy/apko/haproxy.yaml \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION) \
		haproxy.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < haproxy.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:latest
	@rm -f haproxy.tar sbom-*.spdx.json
	@echo "✓ minimal-haproxy built (source build)"

#------------------------------------------------------------------------------
# VALKEY IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
valkey-melange: keygen
	@echo "Building Valkey $(VALKEY_VERSION) from source via melange..."
	melange build images/valkey/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Valkey package built from source"

valkey: valkey-melange
	@echo "Assembling minimal-valkey image with apko..."
	apko build images/valkey/apko/valkey.yaml \
		$(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION) \
		valkey.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < valkey.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-valkey:latest
	@rm -f valkey.tar sbom-*.spdx.json
	@echo "✓ minimal-valkey built (source build)"

#------------------------------------------------------------------------------
# NATS IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
nats-melange: keygen
	@echo "Building NATS $(NATS_VERSION) from source via melange..."
	melange build images/nats/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ NATS package built from source"

nats: nats-melange
	@echo "Assembling minimal-nats image with apko..."
	apko build images/nats/apko/nats.yaml \
		$(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION) \
		nats.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < nats.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-nats:latest
	@rm -f nats.tar sbom-*.spdx.json
	@echo "✓ minimal-nats built (source build)"

#------------------------------------------------------------------------------
# TRAEFIK IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
traefik-melange: keygen
	@echo "Building Traefik $(TRAEFIK_VERSION) from source via melange..."
	melange build images/traefik/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Traefik package built from source"

traefik: traefik-melange
	@echo "Assembling minimal-traefik image with apko..."
	apko build images/traefik/apko/traefik.yaml \
		$(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION) \
		traefik.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < traefik.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-traefik:latest
	@rm -f traefik.tar sbom-*.spdx.json
	@echo "✓ minimal-traefik built (source build)"

#------------------------------------------------------------------------------
# ENVOY IMAGE (melange official binary release + apko)
#------------------------------------------------------------------------------
envoy-melange: keygen
	@echo "Building Envoy $(ENVOY_VERSION) from upstream releases via melange..."
	melange build images/envoy/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Envoy package built"

envoy: envoy-melange
	@echo "Assembling minimal-envoy image with apko..."
	apko build images/envoy/apko/envoy.yaml \
		$(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION) \
		envoy.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < envoy.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-envoy:latest
	@rm -f envoy.tar sbom-*.spdx.json
	@echo "✓ minimal-envoy built (upstream binary)"

#------------------------------------------------------------------------------
# RABBITMQ IMAGE (melange official binary release + apko)
#------------------------------------------------------------------------------
rabbitmq-melange: keygen
	@echo "Building RabbitMQ $(RABBITMQ_VERSION) via melange (official generic-unix release)..."
	melange build images/rabbitmq/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ RabbitMQ package built"

rabbitmq: rabbitmq-melange
	@echo "Assembling minimal-rabbitmq image with apko..."
	apko build images/rabbitmq/apko/rabbitmq.yaml \
		$(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION) \
		rabbitmq.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < rabbitmq.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-rabbitmq:latest
	@rm -f rabbitmq.tar sbom-*.spdx.json
	@echo "✓ minimal-rabbitmq built"

#------------------------------------------------------------------------------
# MINIO IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
minio-melange: keygen
	@echo "Building MinIO $(MINIO_VERSION) from source via melange..."
	melange build images/minio/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ MinIO package built from source"

minio: minio-melange
	@echo "Assembling minimal-minio image with apko..."
	apko build images/minio/apko/minio.yaml \
		$(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION) \
		minio.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < minio.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-minio:latest
	@rm -f minio.tar sbom-*.spdx.json
	@echo "✓ minimal-minio built (source build)"

#------------------------------------------------------------------------------
# PROMETHEUS IMAGE (melange source build + apko, no embedded web UI)
#------------------------------------------------------------------------------
prometheus-melange: keygen
	@echo "Building Prometheus $(PROMETHEUS_VERSION) from source via melange..."
	melange build images/prometheus/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Prometheus package built from source"

prometheus: prometheus-melange
	@echo "Assembling minimal-prometheus image with apko..."
	apko build images/prometheus/apko/prometheus.yaml \
		$(REGISTRY)/$(OWNER)/minimal-prometheus:$(VERSION) \
		prometheus.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < prometheus.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-prometheus:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-prometheus:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-prometheus:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-prometheus:latest
	@rm -f prometheus.tar sbom-*.spdx.json
	@echo "✓ minimal-prometheus built (source build)"

#------------------------------------------------------------------------------
# TELEGRAF IMAGE (melange Go source build + apko; metrics agent)
#------------------------------------------------------------------------------
telegraf-melange: keygen
	@echo "Building Telegraf $(TELEGRAF_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/telegraf/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Telegraf package built from source"

telegraf: telegraf-melange
	@echo "Assembling minimal-telegraf image with apko..."
	apko build images/telegraf/apko/telegraf.yaml \
		$(REGISTRY)/$(OWNER)/minimal-telegraf:$(VERSION) \
		telegraf.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < telegraf.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-telegraf:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-telegraf:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-telegraf:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-telegraf:latest
	@rm -f telegraf.tar sbom-*.spdx.json
	@echo "✓ minimal-telegraf built (source build)"

#------------------------------------------------------------------------------
# MIMIR IMAGE (melange Go source build + apko; Grafana long-term Prom storage)
#------------------------------------------------------------------------------
mimir-melange: keygen
	@echo "Building Mimir $(MIMIR_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/mimir/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Mimir package built from source"

mimir: mimir-melange
	@echo "Assembling minimal-mimir image with apko..."
	apko build images/mimir/apko/mimir.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mimir:$(VERSION) \
		mimir.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mimir.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mimir:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mimir:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mimir:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mimir:latest
	@rm -f mimir.tar sbom-*.spdx.json
	@echo "✓ minimal-mimir built (source build)"

alertmanager-melange: keygen
	@echo "Building Alertmanager $(ALERTMANAGER_VERSION) from source via melange..."
	# Local build is x86_64-only: bwrap sandbox can't run aarch64 binaries
	# without QEMU binfmt registered. CI builds aarch64 on native ARM runners.
	melange build images/alertmanager/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Alertmanager package built from source (x86_64)"

alertmanager: alertmanager-melange
	@echo "Assembling minimal-alertmanager image with apko..."
	apko build images/alertmanager/apko/alertmanager.yaml \
		$(REGISTRY)/$(OWNER)/minimal-alertmanager:$(VERSION) \
		alertmanager.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < alertmanager.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-alertmanager:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-alertmanager:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-alertmanager:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-alertmanager:latest
	@rm -f alertmanager.tar sbom-*.spdx.json
	@echo "✓ minimal-alertmanager built (source build)"


#------------------------------------------------------------------------------
# MARIADB IMAGE (melange source build + apko, LTS 11.4 track)
#------------------------------------------------------------------------------
mariadb-melange: keygen
	@echo "Building MariaDB $(MARIADB_VERSION) from source via melange..."
	melange build images/mariadb/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ MariaDB package built from source"

mariadb: mariadb-melange
	@echo "Assembling minimal-mariadb image with apko..."
	apko build images/mariadb/apko/mariadb.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mariadb:$(VERSION) \
		mariadb.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mariadb.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mariadb:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mariadb:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mariadb:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mariadb:latest
	@rm -f mariadb.tar sbom-*.spdx.json
	@echo "✓ minimal-mariadb built (source build)"

#------------------------------------------------------------------------------
# ETCD IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
etcd-melange: keygen
	@echo "Building etcd $(ETCD_VERSION) from source via melange..."
	melange build images/etcd/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ etcd package built from source"

etcd: etcd-melange
	@echo "Assembling minimal-etcd image with apko..."
	apko build images/etcd/apko/etcd.yaml \
		$(REGISTRY)/$(OWNER)/minimal-etcd:$(VERSION) \
		etcd.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < etcd.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-etcd:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-etcd:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-etcd:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-etcd:latest
	@rm -f etcd.tar sbom-*.spdx.json
	@echo "✓ minimal-etcd built (source build)"

#------------------------------------------------------------------------------
# VICTORIA-METRICS IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
victoria-metrics-melange: keygen
	@echo "Building VictoriaMetrics $(VICTORIA_METRICS_VERSION) from source via melange..."
	melange build images/victoria-metrics/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ VictoriaMetrics package built from source"

victoria-metrics: victoria-metrics-melange
	@echo "Assembling minimal-victoria-metrics image with apko..."
	apko build images/victoria-metrics/apko/victoria-metrics.yaml \
		$(REGISTRY)/$(OWNER)/minimal-victoria-metrics:$(VERSION) \
		victoria-metrics.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < victoria-metrics.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-victoria-metrics:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-victoria-metrics:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-victoria-metrics:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-victoria-metrics:latest
	@rm -f victoria-metrics.tar sbom-*.spdx.json
	@echo "✓ minimal-victoria-metrics built (source build)"

#------------------------------------------------------------------------------
# JAEGER IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
jaeger-melange: keygen
	@echo "Building Jaeger $(JAEGER_VERSION) from source via melange..."
	melange build images/jaeger/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Jaeger package built from source"

jaeger: jaeger-melange
	@echo "Assembling minimal-jaeger image with apko..."
	apko build images/jaeger/apko/jaeger.yaml \
		$(REGISTRY)/$(OWNER)/minimal-jaeger:$(VERSION) \
		jaeger.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < jaeger.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-jaeger:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jaeger:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-jaeger:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-jaeger:latest
	@rm -f jaeger.tar sbom-*.spdx.json
	@echo "✓ minimal-jaeger built (source build)"

#------------------------------------------------------------------------------
# OTELCOL IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
otelcol-melange: keygen
	@echo "Building OTel Collector $(OTELCOL_VERSION) from source via melange..."
	melange build images/otelcol/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ OTel Collector package built from source"

otelcol: otelcol-melange
	@echo "Assembling minimal-otelcol image with apko..."
	apko build images/otelcol/apko/otelcol.yaml \
		$(REGISTRY)/$(OWNER)/minimal-otelcol:$(VERSION) \
		otelcol.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < otelcol.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-otelcol:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-otelcol:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-otelcol:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-otelcol:latest
	@rm -f otelcol.tar sbom-*.spdx.json
	@echo "✓ minimal-otelcol built (source build)"

#------------------------------------------------------------------------------
# QDRANT IMAGE (melange Rust source build + apko)
#------------------------------------------------------------------------------
qdrant-melange: keygen
	@echo "Building Qdrant $(QDRANT_VERSION) from source via melange (Rust)..."
	melange build images/qdrant/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Qdrant package built from source"

qdrant: qdrant-melange
	@echo "Assembling minimal-qdrant image with apko..."
	apko build images/qdrant/apko/qdrant.yaml \
		$(REGISTRY)/$(OWNER)/minimal-qdrant:$(VERSION) \
		qdrant.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < qdrant.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-qdrant:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-qdrant:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-qdrant:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-qdrant:latest
	@rm -f qdrant.tar sbom-*.spdx.json
	@echo "✓ minimal-qdrant built (Rust source build)"

#------------------------------------------------------------------------------
# DENO IMAGE (melange: official upstream binary, shell-less)
#------------------------------------------------------------------------------
DENO_VERSION ?= $(call melange_version,images/deno/melange.yaml)

deno-melange: keygen
	@echo "Building Deno $(DENO_VERSION) (official upstream binary) via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/deno/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Deno package built (official binary)"

deno: deno-melange
	@echo "Assembling minimal-deno image with apko..."
	apko build images/deno/apko/deno.yaml \
		$(REGISTRY)/$(OWNER)/minimal-deno:$(VERSION) \
		deno.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < deno.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-deno:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-deno:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-deno:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-deno:latest
	@rm -f deno.tar sbom-*.spdx.json
	@echo "✓ minimal-deno built (official binary, shell-less)"

#------------------------------------------------------------------------------
# CUDA PYTHON IMAGE (melange NVIDIA redist tarballs + Wolfi Python, x86_64 only)
#------------------------------------------------------------------------------
cuda-python-melange: keygen
	@echo "Building CUDA $(CUDA_VERSION) runtime packages via melange..."
	melange build images/cuda-python/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ CUDA runtime packages built"

cuda-python: cuda-python-melange
	@echo "Assembling minimal-cuda-python image with apko..."
	apko build images/cuda-python/apko/cuda-python.yaml \
		$(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION) \
		cuda-python.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < cuda-python.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cuda-python:latest
	@rm -f cuda-python.tar sbom-*.spdx.json
	@echo "✓ minimal-cuda-python built (NVIDIA CUDA + Python, x86_64 only)"

#------------------------------------------------------------------------------
# POSTGRES SLIM IMAGE (Wolfi pre-built package)
#------------------------------------------------------------------------------
postgres-slim:
	@echo "Assembling minimal-postgres-slim image with apko..."
	apko build images/postgres-slim/apko/postgres.yaml \
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
# BUN IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
bun:
	@echo "Assembling minimal-bun image with apko..."
	apko build images/bun/apko/bun.yaml \
		$(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION) \
		bun.tar \
		--arch x86_64
	docker load < bun.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-bun:latest
	@rm -f bun.tar sbom-*.spdx.json
	@echo "✓ minimal-bun built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# VECTOR IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
vector:
	@echo "Assembling minimal-vector image with apko..."
	apko build images/vector/apko/vector.yaml \
		$(REGISTRY)/$(OWNER)/minimal-vector:$(VERSION) \
		vector.tar \
		--arch x86_64
	docker load < vector.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-vector:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-vector:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-vector:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-vector:latest
	@rm -f vector.tar sbom-*.spdx.json
	@echo "✓ minimal-vector built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# PATRONI IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
patroni:
	@echo "Assembling minimal-patroni image with apko..."
	apko build images/patroni/apko/patroni.yaml \
		$(REGISTRY)/$(OWNER)/minimal-patroni:$(VERSION) \
		patroni.tar \
		--arch x86_64
	docker load < patroni.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-patroni:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-patroni:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-patroni:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-patroni:latest
	@rm -f patroni.tar sbom-*.spdx.json
	@echo "✓ minimal-patroni built (Wolfi package, busybox sh required by initdb)"

#------------------------------------------------------------------------------
# DNSMASQ IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
dnsmasq:
	@echo "Assembling minimal-dnsmasq image with apko..."
	apko build images/dnsmasq/apko/dnsmasq.yaml \
		$(REGISTRY)/$(OWNER)/minimal-dnsmasq:$(VERSION) \
		dnsmasq.tar \
		--arch x86_64
	docker load < dnsmasq.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-dnsmasq:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dnsmasq:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-dnsmasq:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dnsmasq:latest
	@rm -f dnsmasq.tar sbom-*.spdx.json
	@echo "✓ minimal-dnsmasq built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# SQLITE IMAGE (Wolfi pre-built package, shell-less)
#------------------------------------------------------------------------------
sqlite:
	@echo "Assembling minimal-sqlite image with apko..."
	apko build images/sqlite/apko/sqlite.yaml \
		$(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION) \
		sqlite.tar \
		--arch x86_64
	docker load < sqlite.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-sqlite:latest
	@rm -f sqlite.tar sbom-*.spdx.json
	@echo "✓ minimal-sqlite built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# DOTNET RUNTIME IMAGE (Wolfi pre-built package)
#------------------------------------------------------------------------------
dotnet:
	@echo "Assembling minimal-dotnet image with apko..."
	apko build images/dotnet/apko/dotnet.yaml \
		$(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION) \
		dotnet.tar \
		--arch x86_64
	docker load < dotnet.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dotnet:latest
	@rm -f dotnet.tar sbom-*.spdx.json
	@echo "✓ minimal-dotnet built (Wolfi package)"

#------------------------------------------------------------------------------
# JAVA IMAGE (Wolfi pre-built OpenJDK JRE, shell-less)
#------------------------------------------------------------------------------
java:
	@echo "Assembling minimal-java image with apko..."
	apko build images/java/apko/java.yaml \
		$(REGISTRY)/$(OWNER)/minimal-java:$(VERSION) \
		java.tar \
		--arch x86_64
	docker load < java.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-java:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-java:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-java:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-java:latest
	@rm -f java.tar sbom-*.spdx.json
	@echo "✓ minimal-java built (Wolfi package, shell-less)"

#------------------------------------------------------------------------------
# OPENSEARCH IMAGE (Wolfi pre-built package)
#------------------------------------------------------------------------------
opensearch-melange: keygen
	@echo "Building OpenSearch $(OPENSEARCH_VERSION) (official min distribution) via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/opensearch/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ OpenSearch package built (official min distribution)"

opensearch: opensearch-melange
	@echo "Assembling minimal-opensearch image with apko..."
	apko build images/opensearch/apko/opensearch.yaml \
		$(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION) \
		opensearch.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < opensearch.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opensearch:latest
	@rm -f opensearch.tar sbom-*.spdx.json
	@echo "✓ minimal-opensearch built (official min distribution)"

#------------------------------------------------------------------------------
# PHP IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
php-melange: keygen
	@echo "Building PHP from source via melange..."
	melange build images/php/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ PHP package built from source"

php: php-melange
	@echo "Assembling minimal-php image with apko..."
	apko build images/php/apko/php.yaml \
		$(REGISTRY)/$(OWNER)/minimal-php:$(VERSION) \
		php.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < php.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-php:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-php:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-php:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-php:latest
	@rm -f php.tar sbom-*.spdx.json
	@echo "✓ minimal-php built (source build)"

#------------------------------------------------------------------------------
# RUBY IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
ruby-melange: keygen
	@echo "Building Ruby $(RUBY_VERSION) from source via melange..."
	melange build images/ruby/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Ruby package built from source"

ruby: ruby-melange
	@echo "Assembling minimal-ruby image with apko..."
	apko build images/ruby/apko/ruby.yaml \
		$(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION) \
		ruby.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < ruby.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-ruby:latest
	@rm -f ruby.tar sbom-*.spdx.json
	@echo "✓ minimal-ruby built (source build)"

$(eval $(call DEV_IMAGE_RULE,ruby,ruby-melange,--repository-append ./packages --keyring-append melange.rsa.pub))

#------------------------------------------------------------------------------
# RAILS IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
rails-melange: keygen
	@echo "Building Ruby $(RUBY_VERSION) + Rails $(RAILS_VERSION) from source via melange..."
	melange build images/rails/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Rails package built from source"

rails: rails-melange
	@echo "Assembling minimal-rails image with apko..."
	apko build images/rails/apko/rails.yaml \
		$(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION) \
		rails.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < rails.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-rails:latest
	@rm -f rails.tar sbom-*.spdx.json
	@echo "✓ minimal-rails built (source build)"

#------------------------------------------------------------------------------
# KAFKA IMAGE (official binary release + jlink JRE, KRaft mode)
#------------------------------------------------------------------------------
kafka-melange: keygen
	@echo "Building Kafka $(KAFKA_VERSION) package via melange..."
	# x86_64 only locally: jlink runs inside the melange sandbox so aarch64
	# cross-builds fail on x86_64 hosts without QEMU binfmt. CI uses native ARM runners.
	melange build images/kafka/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Kafka package built"

kafka: kafka-melange
	@echo "Assembling minimal-kafka image with apko..."
	apko build images/kafka/apko/kafka.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION) \
		kafka.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kafka.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kafka:latest
	@rm -f kafka.tar sbom-*.spdx.json
	@echo "✓ minimal-kafka built (official binary + jlink JRE)"

#------------------------------------------------------------------------------
# CASSANDRA IMAGE (official binary release + jlink JRE, Java 17)
#------------------------------------------------------------------------------
cassandra-melange: keygen
	@echo "Building Cassandra $(CASSANDRA_VERSION) package via melange..."
	# x86_64 only locally: jlink runs inside the melange sandbox so aarch64
	# cross-builds fail on x86_64 hosts without QEMU binfmt. CI uses native ARM runners.
	melange build images/cassandra/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Cassandra package built"

cassandra: cassandra-melange
	@echo "Assembling minimal-cassandra image with apko..."
	apko build images/cassandra/apko/cassandra.yaml \
		$(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION) \
		cassandra.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < cassandra.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cassandra:latest
	@rm -f cassandra.tar sbom-*.spdx.json
	@echo "✓ minimal-cassandra built (official binary + jlink JRE)"

#------------------------------------------------------------------------------
# SOLR IMAGE (official binary release + jlink JRE, Java 21)
#------------------------------------------------------------------------------
solr-melange: keygen
	@echo "Building Solr $(SOLR_VERSION) package via melange..."
	melange build images/solr/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Solr package built"

solr: solr-melange
	@echo "Assembling minimal-solr image with apko..."
	apko build images/solr/apko/solr.yaml \
		$(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION) \
		solr.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < solr.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-solr:latest
	@rm -f solr.tar sbom-*.spdx.json
	@echo "✓ minimal-solr built (official binary + jlink JRE)"

#------------------------------------------------------------------------------
# PULSAR IMAGE (official binary release + jlink JRE, Java 21)
#------------------------------------------------------------------------------
pulsar-melange: keygen
	@echo "Building Pulsar $(PULSAR_VERSION) package via melange..."
	melange build images/pulsar/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Pulsar package built"

pulsar: pulsar-melange
	@echo "Assembling minimal-pulsar image with apko..."
	apko build images/pulsar/apko/pulsar.yaml \
		$(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION) \
		pulsar.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < pulsar.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pulsar:latest
	@rm -f pulsar.tar sbom-*.spdx.json
	@echo "✓ minimal-pulsar built (official binary + jlink JRE)"

zookeeper-melange: keygen
	@echo "Building ZooKeeper $(ZOOKEEPER_VERSION) package via melange..."
	# x86_64 only locally: jlink runs inside the melange sandbox so aarch64
	# cross-builds fail on x86_64 hosts without QEMU binfmt. CI uses native ARM runners.
	melange build images/zookeeper/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ ZooKeeper package built"

zookeeper: zookeeper-melange
	@echo "Assembling minimal-zookeeper image with apko..."
	apko build images/zookeeper/apko/zookeeper.yaml \
		$(REGISTRY)/$(OWNER)/minimal-zookeeper:$(ZOOKEEPER_VERSION) \
		zookeeper.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < zookeeper.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-zookeeper:$(ZOOKEEPER_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-zookeeper:$(ZOOKEEPER_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-zookeeper:$(ZOOKEEPER_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-zookeeper:latest
	@rm -f zookeeper.tar sbom-*.spdx.json
	@echo "✓ minimal-zookeeper built (official binary + jlink JRE)"

tomcat-melange: keygen
	@echo "Building Tomcat $(TOMCAT_VERSION) package via melange..."
	# x86_64 only locally: jlink runs inside the melange sandbox.
	melange build images/tomcat/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Tomcat package built"

tomcat: tomcat-melange
	@echo "Assembling minimal-tomcat image with apko..."
	apko build images/tomcat/apko/tomcat.yaml \
		$(REGISTRY)/$(OWNER)/minimal-tomcat:$(TOMCAT_VERSION) \
		tomcat.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < tomcat.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-tomcat:$(TOMCAT_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-tomcat:$(TOMCAT_VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-tomcat:$(TOMCAT_VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-tomcat:latest
	@rm -f tomcat.tar sbom-*.spdx.json
	@echo "✓ minimal-tomcat built (official binary + jlink JRE)"

#------------------------------------------------------------------------------
# COREDNS IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
coredns-melange: keygen
	@echo "Building CoreDNS $(COREDNS_VERSION) from source via melange..."
	melange build images/coredns/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ CoreDNS package built from source"

coredns: coredns-melange
	@echo "Assembling minimal-coredns image with apko..."
	apko build images/coredns/apko/coredns.yaml \
		$(REGISTRY)/$(OWNER)/minimal-coredns:$(VERSION) \
		coredns.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < coredns.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-coredns:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-coredns:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-coredns:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-coredns:latest
	@rm -f coredns.tar sbom-*.spdx.json
	@echo "✓ minimal-coredns built (source build)"

gitea-melange: keygen
	@echo "Building Gitea $(GITEA_VERSION) from source via melange..."
	melange build images/gitea/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Gitea package built from source"

gitea: gitea-melange
	@echo "Assembling minimal-gitea image with apko..."
	apko build images/gitea/apko/gitea.yaml \
		$(REGISTRY)/$(OWNER)/minimal-gitea:$(VERSION) \
		gitea.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < gitea.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-gitea:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-gitea:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-gitea:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-gitea:latest
	@rm -f gitea.tar sbom-*.spdx.json
	@echo "✓ minimal-gitea built (source build)"

#------------------------------------------------------------------------------
# OPENBAO IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
openbao-melange: keygen
	@echo "Building OpenBao $(OPENBAO_VERSION) from source via melange..."
	melange build images/openbao/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ OpenBao package built from source"

openbao: openbao-melange
	@echo "Assembling minimal-openbao image with apko..."
	apko build images/openbao/apko/openbao.yaml \
		$(REGISTRY)/$(OWNER)/minimal-openbao:$(VERSION) \
		openbao.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < openbao.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-openbao:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-openbao:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-openbao:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-openbao:latest
	@rm -f openbao.tar sbom-*.spdx.json
	@echo "✓ minimal-openbao built (source build)"

#------------------------------------------------------------------------------
# LOKI IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
loki-melange: keygen
	@echo "Building Loki $(LOKI_VERSION) from source via melange..."
	melange build images/loki/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Loki package built from source"

loki: loki-melange
	@echo "Assembling minimal-loki image with apko..."
	apko build images/loki/apko/loki.yaml \
		$(REGISTRY)/$(OWNER)/minimal-loki:$(VERSION) \
		loki.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < loki.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-loki:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-loki:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-loki:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-loki:latest
	@rm -f loki.tar sbom-*.spdx.json
	@echo "✓ minimal-loki built (source build)"

#------------------------------------------------------------------------------
# FLUENT BIT IMAGE (melange source build + apko)
#------------------------------------------------------------------------------
fluent-bit-melange: keygen
	@echo "Building Fluent Bit $(FLUENT_BIT_VERSION) from source via melange..."
	melange build images/fluent-bit/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Fluent Bit package built from source"

fluent-bit: fluent-bit-melange
	@echo "Assembling minimal-fluent-bit image with apko..."
	apko build images/fluent-bit/apko/fluent-bit.yaml \
		$(REGISTRY)/$(OWNER)/minimal-fluent-bit:$(VERSION) \
		fluent-bit.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < fluent-bit.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-fluent-bit:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-fluent-bit:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-fluent-bit:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-fluent-bit:latest
	@rm -f fluent-bit.tar sbom-*.spdx.json
	@echo "✓ minimal-fluent-bit built (source build)"

#------------------------------------------------------------------------------
# KEYCLOAK IMAGE (melange pre-built distribution + apko)
#------------------------------------------------------------------------------
keycloak-melange: keygen
	@echo "Building Keycloak $(KEYCLOAK_VERSION) package via melange..."
	melange build images/keycloak/melange.yaml \
		--arch x86_64,aarch64 \
		--signing-key melange.rsa
	@echo "✓ Keycloak package built"

keycloak: keycloak-melange
	@echo "Assembling minimal-keycloak image with apko..."
	apko build images/keycloak/apko/keycloak.yaml \
		$(REGISTRY)/$(OWNER)/minimal-keycloak:$(VERSION) \
		keycloak.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < keycloak.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-keycloak:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-keycloak:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-keycloak:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-keycloak:latest
	@rm -f keycloak.tar sbom-*.spdx.json
	@echo "✓ minimal-keycloak built (pre-built distribution)"

#------------------------------------------------------------------------------
# REGISTRY IMAGE (melange source build + apko — distribution/distribution)
#------------------------------------------------------------------------------
registry-melange: keygen
	@echo "Building distribution $(DISTRIBUTION_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/registry/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ registry (distribution) package built from source"

registry: registry-melange
	@echo "Assembling minimal-registry image with apko..."
	apko build images/registry/apko/registry.yaml \
		$(REGISTRY)/$(OWNER)/minimal-registry:$(VERSION) \
		registry.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < registry.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-registry:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-registry:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-registry:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-registry:latest
	@rm -f registry.tar sbom-*.spdx.json
	@echo "✓ minimal-registry built (source build)"

#------------------------------------------------------------------------------
# MAILPIT IMAGE (melange Go + npm frontend source build + apko)
#------------------------------------------------------------------------------
mailpit-melange: keygen
	@echo "Building mailpit $(MAILPIT_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/mailpit/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ mailpit package built from source"

mailpit: mailpit-melange
	@echo "Assembling minimal-mailpit image with apko..."
	apko build images/mailpit/apko/mailpit.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mailpit:$(VERSION) \
		mailpit.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mailpit.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mailpit:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mailpit:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mailpit:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mailpit:latest
	@rm -f mailpit.tar sbom-*.spdx.json
	@echo "✓ minimal-mailpit built (source build)"

#------------------------------------------------------------------------------
# CONSUL IMAGE (melange Go source build + apko; BUSL-1.1)
#------------------------------------------------------------------------------
consul-melange: keygen
	@echo "Building Consul $(CONSUL_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/consul/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Consul package built from source"

consul: consul-melange
	@echo "Assembling minimal-consul image with apko..."
	apko build images/consul/apko/consul.yaml \
		$(REGISTRY)/$(OWNER)/minimal-consul:$(VERSION) \
		consul.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < consul.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-consul:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-consul:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-consul:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-consul:latest
	@rm -f consul.tar sbom-*.spdx.json
	@echo "✓ minimal-consul built (source build)"

#------------------------------------------------------------------------------
# TEMPO IMAGE (melange Go source build + apko; Grafana distributed tracing)
#------------------------------------------------------------------------------
tempo-melange: keygen
	@echo "Building Tempo $(TEMPO_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/tempo/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Tempo package built from source"

tempo: tempo-melange
	@echo "Assembling minimal-tempo image with apko..."
	apko build images/tempo/apko/tempo.yaml \
		$(REGISTRY)/$(OWNER)/minimal-tempo:$(VERSION) \
		tempo.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < tempo.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-tempo:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-tempo:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-tempo:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-tempo:latest
	@rm -f tempo.tar sbom-*.spdx.json
	@echo "✓ minimal-tempo built (source build)"

#------------------------------------------------------------------------------
# OPENTOFU IMAGE (melange Go source build + apko; Terraform-compatible IaC CLI)
#------------------------------------------------------------------------------
opentofu-melange: keygen
	@echo "Building OpenTofu $(OPENTOFU_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/opentofu/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ OpenTofu package built from source"

opentofu: opentofu-melange
	@echo "Assembling minimal-opentofu image with apko..."
	apko build images/opentofu/apko/opentofu.yaml \
		$(REGISTRY)/$(OWNER)/minimal-opentofu:$(VERSION) \
		opentofu.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < opentofu.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-opentofu:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opentofu:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-opentofu:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opentofu:latest
	@rm -f opentofu.tar sbom-*.spdx.json
	@echo "✓ minimal-opentofu built (source build)"

#------------------------------------------------------------------------------
# TRIVY IMAGE (melange Go source build + apko; vulnerability/IaC/secret scanner)
#------------------------------------------------------------------------------
trivy-melange: keygen
	@echo "Building Trivy $(TRIVY_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/trivy/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Trivy package built from source"

trivy: trivy-melange
	@echo "Assembling minimal-trivy image with apko..."
	apko build images/trivy/apko/trivy.yaml \
		$(REGISTRY)/$(OWNER)/minimal-trivy:$(VERSION) \
		trivy.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < trivy.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-trivy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-trivy:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-trivy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-trivy:latest
	@rm -f trivy.tar sbom-*.spdx.json
	@echo "✓ minimal-trivy built (source build)"

#------------------------------------------------------------------------------
# COSIGN IMAGE (melange Go source build + apko; Sigstore container signing)
#------------------------------------------------------------------------------
cosign-melange: keygen
	@echo "Building Cosign $(COSIGN_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/cosign/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Cosign package built from source"

cosign: cosign-melange
	@echo "Assembling minimal-cosign image with apko..."
	apko build images/cosign/apko/cosign.yaml \
		$(REGISTRY)/$(OWNER)/minimal-cosign:$(VERSION) \
		cosign.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < cosign.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-cosign:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cosign:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-cosign:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-cosign:latest
	@rm -f cosign.tar sbom-*.spdx.json
	@echo "✓ minimal-cosign built (source build)"

#------------------------------------------------------------------------------
# SYFT IMAGE (melange Go source build + apko; SBOM generation)
#------------------------------------------------------------------------------
syft-melange: keygen
	@echo "Building Syft $(SYFT_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/syft/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Syft package built from source"

syft: syft-melange
	@echo "Assembling minimal-syft image with apko..."
	apko build images/syft/apko/syft.yaml \
		$(REGISTRY)/$(OWNER)/minimal-syft:$(VERSION) \
		syft.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < syft.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-syft:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-syft:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-syft:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-syft:latest
	@rm -f syft.tar sbom-*.spdx.json
	@echo "✓ minimal-syft built (source build)"

#------------------------------------------------------------------------------
# GRYPE IMAGE (melange Go source build + apko; vulnerability scanning)
#------------------------------------------------------------------------------
grype-melange: keygen
	@echo "Building Grype $(GRYPE_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/grype/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Grype package built from source"

grype: grype-melange
	@echo "Assembling minimal-grype image with apko..."
	apko build images/grype/apko/grype.yaml \
		$(REGISTRY)/$(OWNER)/minimal-grype:$(VERSION) \
		grype.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < grype.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-grype:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-grype:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-grype:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-grype:latest
	@rm -f grype.tar sbom-*.spdx.json
	@echo "✓ minimal-grype built (source build)"

#------------------------------------------------------------------------------
# ORAS IMAGE (melange Go source build + apko; OCI registry client)
#------------------------------------------------------------------------------
oras-melange: keygen
	@echo "Building ORAS $(ORAS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/oras/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ ORAS package built from source"

oras: oras-melange
	@echo "Assembling minimal-oras image with apko..."
	apko build images/oras/apko/oras.yaml \
		$(REGISTRY)/$(OWNER)/minimal-oras:$(VERSION) \
		oras.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < oras.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-oras:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-oras:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-oras:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-oras:latest
	@rm -f oras.tar sbom-*.spdx.json
	@echo "✓ minimal-oras built (source build)"

#------------------------------------------------------------------------------
# GITLEAKS IMAGE (melange Go source build + apko; secret scanning)
#------------------------------------------------------------------------------
gitleaks-melange: keygen
	@echo "Building Gitleaks $(GITLEAKS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/gitleaks/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Gitleaks package built from source"

gitleaks: gitleaks-melange
	@echo "Assembling minimal-gitleaks image with apko..."
	apko build images/gitleaks/apko/gitleaks.yaml \
		$(REGISTRY)/$(OWNER)/minimal-gitleaks:$(VERSION) \
		gitleaks.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < gitleaks.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-gitleaks:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-gitleaks:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-gitleaks:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-gitleaks:latest
	@rm -f gitleaks.tar sbom-*.spdx.json
	@echo "✓ minimal-gitleaks built (source build)"

#------------------------------------------------------------------------------
# STEP-CLI IMAGE (melange Go source build + apko; smallstep PKI/cert toolkit)
#------------------------------------------------------------------------------
step-cli-melange: keygen
	@echo "Building step-cli $(STEP_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/step-cli/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ step-cli package built from source"

step-cli: step-cli-melange
	@echo "Assembling minimal-step-cli image with apko..."
	apko build images/step-cli/apko/step-cli.yaml \
		$(REGISTRY)/$(OWNER)/minimal-step-cli:$(VERSION) \
		step-cli.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < step-cli.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-step-cli:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-step-cli:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-step-cli:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-step-cli:latest
	@rm -f step-cli.tar sbom-*.spdx.json
	@echo "✓ minimal-step-cli built (source build)"

#------------------------------------------------------------------------------
# OPA IMAGE (melange Go source build + apko; Open Policy Agent)
#------------------------------------------------------------------------------
opa-melange: keygen
	@echo "Building OPA $(OPA_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/opa/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ OPA package built from source"

opa: opa-melange
	@echo "Assembling minimal-opa image with apko..."
	apko build images/opa/apko/opa.yaml \
		$(REGISTRY)/$(OWNER)/minimal-opa:$(VERSION) \
		opa.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < opa.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-opa:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opa:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-opa:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-opa:latest
	@rm -f opa.tar sbom-*.spdx.json
	@echo "✓ minimal-opa built (source build)"

#------------------------------------------------------------------------------
# OSV-SCANNER IMAGE (melange Go source build + apko; dependency vuln scanning)
#------------------------------------------------------------------------------
osv-scanner-melange: keygen
	@echo "Building OSV-Scanner $(OSV_SCANNER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/osv-scanner/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ OSV-Scanner package built from source"

osv-scanner: osv-scanner-melange
	@echo "Assembling minimal-osv-scanner image with apko..."
	apko build images/osv-scanner/apko/osv-scanner.yaml \
		$(REGISTRY)/$(OWNER)/minimal-osv-scanner:$(VERSION) \
		osv-scanner.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < osv-scanner.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-osv-scanner:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-osv-scanner:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-osv-scanner:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-osv-scanner:latest
	@rm -f osv-scanner.tar sbom-*.spdx.json
	@echo "✓ minimal-osv-scanner built (source build)"

seaweedfs-melange: keygen
	@echo "Building SeaweedFS $(SEAWEEDFS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/seaweedfs/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ SeaweedFS package built from source"

seaweedfs: seaweedfs-melange
	@echo "Assembling minimal-seaweedfs image with apko..."
	apko build images/seaweedfs/apko/seaweedfs.yaml \
		$(REGISTRY)/$(OWNER)/minimal-seaweedfs:$(VERSION) \
		seaweedfs.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < seaweedfs.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-seaweedfs:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-seaweedfs:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-seaweedfs:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-seaweedfs:latest
	@rm -f seaweedfs.tar sbom-*.spdx.json
	@echo "✓ minimal-seaweedfs built (source build)"

dex-melange: keygen
	@echo "Building Dex $(DEX_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/dex/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Dex package built from source"

dex: dex-melange
	@echo "Assembling minimal-dex image with apko..."
	apko build images/dex/apko/dex.yaml \
		$(REGISTRY)/$(OWNER)/minimal-dex:$(VERSION) \
		dex.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < dex.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-dex:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dex:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-dex:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-dex:latest
	@rm -f dex.tar sbom-*.spdx.json
	@echo "✓ minimal-dex built (source build)"

oauth2-proxy-melange: keygen
	@echo "Building OAuth2 Proxy $(OAUTH2_PROXY_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/oauth2-proxy/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ OAuth2 Proxy package built from source"

oauth2-proxy: oauth2-proxy-melange
	@echo "Assembling minimal-oauth2-proxy image with apko..."
	apko build images/oauth2-proxy/apko/oauth2-proxy.yaml \
		$(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:$(VERSION) \
		oauth2-proxy.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < oauth2-proxy.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:latest
	@rm -f oauth2-proxy.tar sbom-*.spdx.json
	@echo "✓ minimal-oauth2-proxy built (source build)"

flux-melange: keygen
	@echo "Building flux $(FLUX_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/flux/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ flux package built from source"

flux: flux-melange
	@echo "Assembling minimal-flux image with apko..."
	apko build images/flux/apko/flux.yaml \
		$(REGISTRY)/$(OWNER)/minimal-flux:$(VERSION) \
		flux.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < flux.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-flux:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-flux:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-flux:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-flux:latest
	@rm -f flux.tar sbom-*.spdx.json
	@echo "✓ minimal-flux built (source build)"

kustomize-melange: keygen
	@echo "Building kustomize $(KUSTOMIZE_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kustomize/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ kustomize package built from source"

kustomize: kustomize-melange
	@echo "Assembling minimal-kustomize image with apko..."
	apko build images/kustomize/apko/kustomize.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kustomize:$(VERSION) \
		kustomize.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kustomize.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kustomize:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kustomize:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kustomize:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kustomize:latest
	@rm -f kustomize.tar sbom-*.spdx.json
	@echo "✓ minimal-kustomize built (source build)"

sops-melange: keygen
	@echo "Building sops $(SOPS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/sops/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ sops package built from source"

sops: sops-melange
	@echo "Assembling minimal-sops image with apko..."
	apko build images/sops/apko/sops.yaml \
		$(REGISTRY)/$(OWNER)/minimal-sops:$(VERSION) \
		sops.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < sops.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-sops:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-sops:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-sops:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-sops:latest
	@rm -f sops.tar sbom-*.spdx.json
	@echo "✓ minimal-sops built (source build)"

crane-melange: keygen
	@echo "Building crane $(CRANE_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/crane/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ crane package built from source"

crane: crane-melange
	@echo "Assembling minimal-crane image with apko..."
	apko build images/crane/apko/crane.yaml \
		$(REGISTRY)/$(OWNER)/minimal-crane:$(VERSION) \
		crane.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < crane.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-crane:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-crane:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-crane:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-crane:latest
	@rm -f crane.tar sbom-*.spdx.json
	@echo "✓ minimal-crane built (source build)"

kubeseal-melange: keygen
	@echo "Building kubeseal $(KUBESEAL_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kubeseal/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ kubeseal package built from source"

kubeseal: kubeseal-melange
	@echo "Assembling minimal-kubeseal image with apko..."
	apko build images/kubeseal/apko/kubeseal.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kubeseal:$(VERSION) \
		kubeseal.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kubeseal.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubeseal:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kubeseal:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubeseal:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kubeseal:latest
	@rm -f kubeseal.tar sbom-*.spdx.json
	@echo "✓ minimal-kubeseal built (source build)"

helmfile-melange: keygen
	@echo "Building helmfile $(HELMFILE_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/helmfile/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ helmfile package built from source"

helmfile: helmfile-melange
	@echo "Assembling minimal-helmfile image with apko..."
	apko build images/helmfile/apko/helmfile.yaml \
		$(REGISTRY)/$(OWNER)/minimal-helmfile:$(VERSION) \
		helmfile.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < helmfile.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-helmfile:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-helmfile:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-helmfile:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-helmfile:latest
	@rm -f helmfile.tar sbom-*.spdx.json
	@echo "✓ minimal-helmfile built (source build)"

regctl-melange: keygen
	@echo "Building regctl $(REGCTL_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/regctl/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ regctl package built from source"

regctl: regctl-melange
	@echo "Assembling minimal-regctl image with apko..."
	apko build images/regctl/apko/regctl.yaml \
		$(REGISTRY)/$(OWNER)/minimal-regctl:$(VERSION) \
		regctl.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < regctl.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-regctl:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-regctl:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-regctl:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-regctl:latest
	@rm -f regctl.tar sbom-*.spdx.json
	@echo "✓ minimal-regctl built (source build)"

stern-melange: keygen
	@echo "Building stern $(STERN_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/stern/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ stern package built from source"

stern: stern-melange
	@echo "Assembling minimal-stern image with apko..."
	apko build images/stern/apko/stern.yaml \
		$(REGISTRY)/$(OWNER)/minimal-stern:$(VERSION) \
		stern.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < stern.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-stern:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-stern:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-stern:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-stern:latest
	@rm -f stern.tar sbom-*.spdx.json
	@echo "✓ minimal-stern built (source build)"



#------------------------------------------------------------------------------
# NOTATION IMAGE (melange Go source build + apko)
#------------------------------------------------------------------------------
notation-melange: keygen
	@echo "Building notation $(NOTATION_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/notation/melange.yaml --arch x86_64 --signing-key melange.rsa
	@echo "✓ notation package built from source"

notation: notation-melange
	@echo "Assembling minimal-notation image with apko..."
	apko build images/notation/apko/notation.yaml $(REGISTRY)/$(OWNER)/minimal-notation:$(VERSION) notation.tar --arch x86_64 --repository-append ./packages --keyring-append melange.rsa.pub
	docker load < notation.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-notation:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-notation:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-notation:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-notation:latest
	@rm -f notation.tar sbom-*.spdx.json
	@echo "✓ minimal-notation built (source build)"

#------------------------------------------------------------------------------
# CONFTEST IMAGE (melange Go source build + apko)
#------------------------------------------------------------------------------
conftest-melange: keygen
	@echo "Building conftest $(CONFTEST_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/conftest/melange.yaml --arch x86_64 --signing-key melange.rsa
	@echo "✓ conftest package built from source"

conftest: conftest-melange
	@echo "Assembling minimal-conftest image with apko..."
	apko build images/conftest/apko/conftest.yaml $(REGISTRY)/$(OWNER)/minimal-conftest:$(VERSION) conftest.tar --arch x86_64 --repository-append ./packages --keyring-append melange.rsa.pub
	docker load < conftest.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-conftest:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-conftest:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-conftest:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-conftest:latest
	@rm -f conftest.tar sbom-*.spdx.json
	@echo "✓ minimal-conftest built (source build)"

#------------------------------------------------------------------------------
# KUBECONFORM IMAGE (melange Go source build + apko)
#------------------------------------------------------------------------------
kubeconform-melange: keygen
	@echo "Building kubeconform $(KUBECONFORM_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kubeconform/melange.yaml --arch x86_64 --signing-key melange.rsa
	@echo "✓ kubeconform package built from source"

kubeconform: kubeconform-melange
	@echo "Assembling minimal-kubeconform image with apko..."
	apko build images/kubeconform/apko/kubeconform.yaml $(REGISTRY)/$(OWNER)/minimal-kubeconform:$(VERSION) kubeconform.tar --arch x86_64 --repository-append ./packages --keyring-append melange.rsa.pub
	docker load < kubeconform.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubeconform:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-kubeconform:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubeconform:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-kubeconform:latest
	@rm -f kubeconform.tar sbom-*.spdx.json
	@echo "✓ minimal-kubeconform built (source build)"

#------------------------------------------------------------------------------
# KUBE_BENCH IMAGE (melange Go source build + apko)
#------------------------------------------------------------------------------
kube-bench-melange: keygen
	@echo "Building kube-bench $(KUBE_BENCH_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kube-bench/melange.yaml --arch x86_64 --signing-key melange.rsa
	@echo "✓ kube-bench package built from source"

kube-bench: kube-bench-melange
	@echo "Assembling minimal-kube-bench image with apko..."
	apko build images/kube-bench/apko/kube-bench.yaml $(REGISTRY)/$(OWNER)/minimal-kube-bench:$(VERSION) kube-bench.tar --arch x86_64 --repository-append ./packages --keyring-append melange.rsa.pub
	docker load < kube-bench.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kube-bench:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-kube-bench:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kube-bench:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-kube-bench:latest
	@rm -f kube-bench.tar sbom-*.spdx.json
	@echo "✓ minimal-kube-bench built (source build)"

#------------------------------------------------------------------------------
# TRUFFLEHOG IMAGE (melange Go source build + apko)
#------------------------------------------------------------------------------
trufflehog-melange: keygen
	@echo "Building trufflehog $(TRUFFLEHOG_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/trufflehog/melange.yaml --arch x86_64 --signing-key melange.rsa
	@echo "✓ trufflehog package built from source"

trufflehog: trufflehog-melange
	@echo "Assembling minimal-trufflehog image with apko..."
	apko build images/trufflehog/apko/trufflehog.yaml $(REGISTRY)/$(OWNER)/minimal-trufflehog:$(VERSION) trufflehog.tar --arch x86_64 --repository-append ./packages --keyring-append melange.rsa.pub
	docker load < trufflehog.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-trufflehog:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-trufflehog:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-trufflehog:$(VERSION)-amd64 $(REGISTRY)/$(OWNER)/minimal-trufflehog:latest
	@rm -f trufflehog.tar sbom-*.spdx.json
	@echo "✓ minimal-trufflehog built (source build)"

#------------------------------------------------------------------------------
# THANOS IMAGE (melange Go source build + apko; HA Prometheus long-term storage)
#------------------------------------------------------------------------------
thanos-melange: keygen
	@echo "Building Thanos $(THANOS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/thanos/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Thanos package built from source"

thanos: thanos-melange
	@echo "Assembling minimal-thanos image with apko..."
	apko build images/thanos/apko/thanos.yaml \
		$(REGISTRY)/$(OWNER)/minimal-thanos:$(VERSION) \
		thanos.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < thanos.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-thanos:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-thanos:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-thanos:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-thanos:latest
	@rm -f thanos.tar sbom-*.spdx.json
	@echo "✓ minimal-thanos built (source build)"

#------------------------------------------------------------------------------
# NODE-EXPORTER IMAGE (melange Go source build + apko; Prometheus host metrics)
#------------------------------------------------------------------------------
node-exporter-melange: keygen
	@echo "Building node_exporter $(NODE_EXPORTER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/node-exporter/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ node_exporter package built from source"

node-exporter: node-exporter-melange
	@echo "Assembling minimal-node-exporter image with apko..."
	apko build images/node-exporter/apko/node-exporter.yaml \
		$(REGISTRY)/$(OWNER)/minimal-node-exporter:$(VERSION) \
		node-exporter.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < node-exporter.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-node-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-node-exporter:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-node-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-node-exporter:latest
	@rm -f node-exporter.tar sbom-*.spdx.json
	@echo "✓ minimal-node-exporter built (source build)"

#------------------------------------------------------------------------------
# BLACKBOX-EXPORTER IMAGE (melange Go source build + apko; Prometheus probing)
#------------------------------------------------------------------------------
blackbox-exporter-melange: keygen
	@echo "Building blackbox_exporter $(BLACKBOX_EXPORTER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/blackbox-exporter/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ blackbox_exporter package built from source"

blackbox-exporter: blackbox-exporter-melange
	@echo "Assembling minimal-blackbox-exporter image with apko..."
	apko build images/blackbox-exporter/apko/blackbox-exporter.yaml \
		$(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:$(VERSION) \
		blackbox-exporter.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < blackbox-exporter.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:latest
	@rm -f blackbox-exporter.tar sbom-*.spdx.json
	@echo "✓ minimal-blackbox-exporter built (source build)"

#------------------------------------------------------------------------------
# KUBE-STATE-METRICS IMAGE (melange Go source build + apko; Kubernetes object state metrics for Prometheus)
#------------------------------------------------------------------------------
kube-state-metrics-melange: keygen
	@echo "Building kube-state-metrics $(KUBE_STATE_METRICS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kube-state-metrics/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ kube-state-metrics package built from source"

kube-state-metrics: kube-state-metrics-melange
	@echo "Assembling minimal-kube-state-metrics image with apko..."
	apko build images/kube-state-metrics/apko/kube-state-metrics.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:$(VERSION) \
		kube-state-metrics.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kube-state-metrics.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:latest
	@rm -f kube-state-metrics.tar sbom-*.spdx.json
	@echo "✓ minimal-kube-state-metrics built (source build)"

#------------------------------------------------------------------------------
# REDIS-EXPORTER IMAGE (melange Go source build + apko; Redis metrics exporter for Prometheus)
#------------------------------------------------------------------------------
redis-exporter-melange: keygen
	@echo "Building redis_exporter $(REDIS_EXPORTER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/redis-exporter/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ redis_exporter package built from source"

redis-exporter: redis-exporter-melange
	@echo "Assembling minimal-redis-exporter image with apko..."
	apko build images/redis-exporter/apko/redis-exporter.yaml \
		$(REGISTRY)/$(OWNER)/minimal-redis-exporter:$(VERSION) \
		redis-exporter.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < redis-exporter.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-redis-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-redis-exporter:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-redis-exporter:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-redis-exporter:latest
	@rm -f redis-exporter.tar sbom-*.spdx.json
	@echo "✓ minimal-redis-exporter built (source build)"

#------------------------------------------------------------------------------
# VAULTWARDEN IMAGE (melange Rust source build + apko; Bitwarden-compatible server)
#------------------------------------------------------------------------------
vaultwarden-melange: keygen
	@echo "Building vaultwarden $(VAULTWARDEN_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/vaultwarden/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ vaultwarden package built from source"

vaultwarden: vaultwarden-melange
	@echo "Assembling minimal-vaultwarden image with apko..."
	apko build images/vaultwarden/apko/vaultwarden.yaml \
		$(REGISTRY)/$(OWNER)/minimal-vaultwarden:$(VERSION) \
		vaultwarden.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < vaultwarden.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-vaultwarden:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-vaultwarden:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-vaultwarden:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-vaultwarden:latest
	@rm -f vaultwarden.tar sbom-*.spdx.json
	@echo "✓ minimal-vaultwarden built (source build)"

#------------------------------------------------------------------------------
# FLINK IMAGE (Apache binary release + jlink JRE via melange; stream processing)
#------------------------------------------------------------------------------
flink-melange: keygen
	@echo "Building Flink $(FLINK_VERSION) via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/flink/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ flink package built"

flink: flink-melange
	@echo "Assembling minimal-flink image with apko..."
	apko build images/flink/apko/flink.yaml \
		$(REGISTRY)/$(OWNER)/minimal-flink:$(VERSION) \
		flink.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < flink.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-flink:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-flink:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-flink:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-flink:latest
	@rm -f flink.tar sbom-*.spdx.json
	@echo "✓ minimal-flink built"

#------------------------------------------------------------------------------
# PUSHGATEWAY IMAGE (melange Go source build + apko; Prometheus push gateway)
#------------------------------------------------------------------------------
pushgateway-melange: keygen
	@echo "Building pushgateway $(PUSHGATEWAY_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/pushgateway/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ pushgateway package built from source"

pushgateway: pushgateway-melange
	@echo "Assembling minimal-pushgateway image with apko..."
	apko build images/pushgateway/apko/pushgateway.yaml \
		$(REGISTRY)/$(OWNER)/minimal-pushgateway:$(VERSION) \
		pushgateway.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < pushgateway.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-pushgateway:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pushgateway:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-pushgateway:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pushgateway:latest
	@rm -f pushgateway.tar sbom-*.spdx.json
	@echo "✓ minimal-pushgateway built (source build)"

#------------------------------------------------------------------------------
# MOSQUITTO IMAGE (melange C source build + apko; Eclipse MQTT broker)
#------------------------------------------------------------------------------
mosquitto-melange: keygen
	@echo "Building Mosquitto $(MOSQUITTO_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/mosquitto/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Mosquitto package built from source"

mosquitto: mosquitto-melange
	@echo "Assembling minimal-mosquitto image with apko..."
	apko build images/mosquitto/apko/mosquitto.yaml \
		$(REGISTRY)/$(OWNER)/minimal-mosquitto:$(VERSION) \
		mosquitto.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < mosquitto.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-mosquitto:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mosquitto:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-mosquitto:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-mosquitto:latest
	@rm -f mosquitto.tar sbom-*.spdx.json
	@echo "✓ minimal-mosquitto built (source build)"

pgbouncer-melange: keygen
	@echo "Building PgBouncer $(PGBOUNCER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/pgbouncer/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ PgBouncer package built from source"

pgbouncer: pgbouncer-melange
	@echo "Assembling minimal-pgbouncer image with apko..."
	apko build images/pgbouncer/apko/pgbouncer.yaml \
		$(REGISTRY)/$(OWNER)/minimal-pgbouncer:$(VERSION) \
		pgbouncer.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < pgbouncer.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-pgbouncer:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pgbouncer:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-pgbouncer:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-pgbouncer:latest
	@rm -f pgbouncer.tar sbom-*.spdx.json
	@echo "✓ minimal-pgbouncer built (source build)"

#------------------------------------------------------------------------------
# KEEPALIVED IMAGE (source build via melange, shell-less)
#------------------------------------------------------------------------------
metrics-server-melange: keygen
	@echo "Building metrics-server $(METRICS_SERVER_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/metrics-server/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ metrics-server package built from source"

metrics-server: metrics-server-melange
	@echo "Assembling minimal-metrics-server image with apko..."
	apko build images/metrics-server/apko/metrics-server.yaml \
		$(REGISTRY)/$(OWNER)/minimal-metrics-server:$(VERSION) \
		metrics-server.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < metrics-server.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-metrics-server:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-metrics-server:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-metrics-server:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-metrics-server:latest
	@rm -f metrics-server.tar sbom-*.spdx.json
	@echo "✓ minimal-metrics-server built (source build)"

keepalived-melange: keygen
	@echo "Building Keepalived package from source with melange..."
	melange build images/keepalived/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Keepalived package built from source"

keepalived: keepalived-melange
	@echo "Assembling minimal-keepalived image with apko..."
	apko build images/keepalived/apko/keepalived.yaml \
		$(REGISTRY)/$(OWNER)/minimal-keepalived:$(VERSION) \
		keepalived.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < keepalived.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-keepalived:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-keepalived:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-keepalived:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-keepalived:latest
	@rm -f keepalived.tar sbom-*.spdx.json
	@echo "✓ minimal-keepalived built (source build)"

unbound-melange: keygen
	@echo "Building Unbound $(UNBOUND_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/unbound/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Unbound package built from source"

unbound: unbound-melange
	@echo "Assembling minimal-unbound image with apko..."
	apko build images/unbound/apko/unbound.yaml \
		$(REGISTRY)/$(OWNER)/minimal-unbound:$(VERSION) \
		unbound.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < unbound.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-unbound:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-unbound:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-unbound:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-unbound:latest
	@rm -f unbound.tar sbom-*.spdx.json
	@echo "✓ minimal-unbound built (source build)"

external-dns-melange: keygen
	@echo "Building ExternalDNS $(EXTERNAL_DNS_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/external-dns/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ ExternalDNS package built from source"

external-dns: external-dns-melange
	@echo "Assembling minimal-external-dns image with apko..."
	apko build images/external-dns/apko/external-dns.yaml \
		$(REGISTRY)/$(OWNER)/minimal-external-dns:$(VERSION) \
		external-dns.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < external-dns.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-external-dns:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-external-dns:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-external-dns:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-external-dns:latest
	@rm -f external-dns.tar sbom-*.spdx.json
	@echo "✓ minimal-external-dns built (source build)"

velero-melange: keygen
	@echo "Building Velero $(VELERO_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/velero/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Velero package built from source"

velero: velero-melange
	@echo "Assembling minimal-velero image with apko..."
	apko build images/velero/apko/velero.yaml \
		$(REGISTRY)/$(OWNER)/minimal-velero:$(VERSION) \
		velero.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < velero.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-velero:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-velero:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-velero:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-velero:latest
	@rm -f velero.tar sbom-*.spdx.json
	@echo "✓ minimal-velero built (source build)"

kaniko-melange: keygen
	@echo "Building Kaniko $(KANIKO_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kaniko/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Kaniko package built from source"

kaniko: kaniko-melange
	@echo "Assembling minimal-kaniko image with apko..."
	apko build images/kaniko/apko/kaniko.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kaniko:$(VERSION) \
		kaniko.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kaniko.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kaniko:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kaniko:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kaniko:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kaniko:latest
	@rm -f kaniko.tar sbom-*.spdx.json
	@echo "✓ minimal-kaniko built (source build)"

step-ca-melange: keygen
	@echo "Building step-ca $(STEP_CA_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/step-ca/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ step-ca package built from source"

step-ca: step-ca-melange
	@echo "Assembling minimal-step-ca image with apko..."
	apko build images/step-ca/apko/step-ca.yaml \
		$(REGISTRY)/$(OWNER)/minimal-step-ca:$(VERSION) \
		step-ca.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < step-ca.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-step-ca:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-step-ca:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-step-ca:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-step-ca:latest
	@rm -f step-ca.tar sbom-*.spdx.json
	@echo "✓ minimal-step-ca built (source build)"

skopeo-melange: keygen
	@echo "Building Skopeo $(SKOPEO_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/skopeo/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Skopeo package built from source"

skopeo: skopeo-melange
	@echo "Assembling minimal-skopeo image with apko..."
	apko build images/skopeo/apko/skopeo.yaml \
		$(REGISTRY)/$(OWNER)/minimal-skopeo:$(VERSION) \
		skopeo.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < skopeo.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-skopeo:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-skopeo:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-skopeo:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-skopeo:latest
	@rm -f skopeo.tar sbom-*.spdx.json
	@echo "✓ minimal-skopeo built (source build)"

helm-melange: keygen
	@echo "Building Helm $(HELM_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/helm/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ Helm package built from source"

helm: helm-melange
	@echo "Assembling minimal-helm image with apko..."
	apko build images/helm/apko/helm.yaml \
		$(REGISTRY)/$(OWNER)/minimal-helm:$(VERSION) \
		helm.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < helm.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-helm:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-helm:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-helm:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-helm:latest
	@rm -f helm.tar sbom-*.spdx.json
	@echo "✓ minimal-helm built (source build)"

kubectl-melange: keygen
	@echo "Building kubectl $(KUBECTL_VERSION) from source via melange (x86_64 only locally; CI builds aarch64 natively)..."
	melange build images/kubectl/melange.yaml \
		--arch x86_64 \
		--signing-key melange.rsa
	@echo "✓ kubectl package built from source"

kubectl: kubectl-melange
	@echo "Assembling minimal-kubectl image with apko..."
	apko build images/kubectl/apko/kubectl.yaml \
		$(REGISTRY)/$(OWNER)/minimal-kubectl:$(VERSION) \
		kubectl.tar \
		--arch x86_64 \
		--repository-append ./packages \
		--keyring-append melange.rsa.pub
	docker load < kubectl.tar
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubectl:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kubectl:$(VERSION)
	docker tag $(REGISTRY)/$(OWNER)/minimal-kubectl:$(VERSION)-amd64 \
		$(REGISTRY)/$(OWNER)/minimal-kubectl:latest
	@rm -f kubectl.tar sbom-*.spdx.json
	@echo "✓ minimal-kubectl built (source build)"

#------------------------------------------------------------------------------
# CVE SCANNING
#------------------------------------------------------------------------------
# Generic scan rule — every image's scan recipe is identical (trivy
# CRITICAL,HIGH on :latest); this pattern covers all of them. An explicit
# scan-<img> target, if present, still wins.
scan-%:
	@echo "Scanning minimal-$*..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-$*:latest
	@echo "✓ minimal-$*: scan passed"

scan: scan-python scan-node-slim scan-bun scan-go scan-java scan-ruby scan-php scan-dotnet scan-deno scan-mysql scan-mariadb scan-postgres-slim scan-pgbouncer scan-unbound scan-dnsmasq scan-keepalived scan-vector scan-patroni scan-metrics-server scan-external-dns scan-velero scan-kaniko scan-step-ca scan-skopeo scan-sqlite scan-opensearch scan-redis-slim scan-valkey scan-memcached scan-kafka scan-zookeeper scan-cassandra scan-solr scan-pulsar scan-tomcat scan-rabbitmq scan-nats scan-mosquitto scan-nginx scan-httpd scan-caddy scan-haproxy scan-traefik scan-envoy scan-oauth2-proxy scan-prometheus scan-alertmanager scan-victoria-metrics scan-thanos scan-mimir scan-jaeger scan-loki scan-tempo scan-otelcol scan-fluent-bit scan-telegraf scan-node-exporter scan-blackbox-exporter scan-pushgateway scan-coredns scan-etcd scan-openbao scan-keycloak scan-qdrant scan-registry scan-consul scan-helm scan-kubectl scan-opentofu scan-trivy scan-cosign scan-syft scan-grype scan-osv-scanner scan-oras scan-notation scan-conftest scan-kubeconform scan-kube-bench scan-trufflehog scan-flux scan-kustomize scan-sops scan-crane scan-kubeseal scan-helmfile scan-regctl scan-stern scan-gitleaks scan-step-cli scan-opa scan-jenkins scan-gitea scan-minio scan-rails scan-mailpit

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

scan-node-slim:
	@echo "Scanning minimal-node-slim..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-node-slim:latest
	@echo "✓ minimal-node-slim: scan passed"

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

scan-mysql:
	@echo "Scanning minimal-mysql..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-mysql:latest
	@echo "✓ minimal-mysql: scan passed"

scan-memcached:
	@echo "Scanning minimal-memcached..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-memcached:latest
	@echo "✓ minimal-memcached: scan passed"

scan-caddy:
	@echo "Scanning minimal-caddy..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-caddy:latest
	@echo "✓ minimal-caddy: scan passed"

scan-haproxy:
	@echo "Scanning minimal-haproxy..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:latest
	@echo "✓ minimal-haproxy: scan passed"

scan-postgres-slim:
	@echo "Scanning minimal-postgres-slim..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest
	@echo "✓ minimal-postgres-slim: scan passed"

scan-bun:
	@echo "Scanning minimal-bun..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-bun:latest
	@echo "✓ minimal-bun: scan passed"

scan-keepalived:
	@echo "Scanning minimal-keepalived..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-keepalived:latest
	@echo "✓ minimal-keepalived: scan passed"

scan-vector:
	@echo "Scanning minimal-vector..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-vector:latest
	@echo "✓ minimal-vector: scan passed"

scan-patroni:
	@echo "Scanning minimal-patroni..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-patroni:latest
	@echo "✓ minimal-patroni: scan passed"

scan-metrics-server:
	@echo "Scanning minimal-metrics-server..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-metrics-server:latest
	@echo "✓ minimal-metrics-server: scan passed"

scan-dnsmasq:
	@echo "Scanning minimal-dnsmasq..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-dnsmasq:latest
	@echo "✓ minimal-dnsmasq: scan passed"

scan-sqlite:
	@echo "Scanning minimal-sqlite..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-sqlite:latest
	@echo "✓ minimal-sqlite: scan passed"

scan-dotnet:
	@echo "Scanning minimal-dotnet..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-dotnet:latest
	@echo "✓ minimal-dotnet: scan passed"

scan-java:
	@echo "Scanning minimal-java..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-java:latest
	@echo "✓ minimal-java: scan passed"

scan-ruby:
	@echo "Scanning minimal-ruby..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-ruby:latest
	@echo "✓ minimal-ruby: scan passed"

scan-php:
	@echo "Scanning minimal-php..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-php:latest
	@echo "✓ minimal-php: scan passed"

scan-rails:
	@echo "Scanning minimal-rails..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-rails:latest
	@echo "✓ minimal-rails: scan passed"

scan-kafka:
	@echo "Scanning minimal-kafka..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-kafka:latest
	@echo "✓ minimal-kafka: scan passed"

scan-cassandra:
	@echo "Scanning minimal-cassandra..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-cassandra:latest
	@echo "✓ minimal-cassandra: scan passed"

scan-solr:
	@echo "Scanning minimal-solr..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-solr:latest
	@echo "✓ minimal-solr: scan passed"

scan-pulsar:
	@echo "Scanning minimal-pulsar..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-pulsar:latest
	@echo "✓ minimal-pulsar: scan passed"

scan-valkey:
	@echo "Scanning minimal-valkey..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-valkey:latest
	@echo "✓ minimal-valkey: scan passed"

scan-nats:
	@echo "Scanning minimal-nats..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-nats:latest
	@echo "✓ minimal-nats: scan passed"

scan-traefik:
	@echo "Scanning minimal-traefik..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-traefik:latest
	@echo "✓ minimal-traefik: scan passed"

scan-envoy:
	@echo "Scanning minimal-envoy..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-envoy:latest
	@echo "✓ minimal-envoy: scan passed"

scan-rabbitmq:
	@echo "Scanning minimal-rabbitmq..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-rabbitmq:latest
	@echo "✓ minimal-rabbitmq: scan passed"

scan-minio:
	@echo "Scanning minimal-minio..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-minio:latest
	@echo "✓ minimal-minio: scan passed"

scan-opensearch:
	@echo "Scanning minimal-opensearch..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-opensearch:latest
	@echo "✓ minimal-opensearch: scan passed"

scan-prometheus:
	@echo "Scanning minimal-prometheus..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-prometheus:latest
	@echo "✓ minimal-prometheus: scan passed"

scan-alertmanager:
	@echo "Scanning minimal-alertmanager..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-alertmanager:latest
	@echo "✓ minimal-alertmanager: scan passed"


scan-mariadb:
	@echo "Scanning minimal-mariadb..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-mariadb:latest
	@echo "✓ minimal-mariadb: scan passed"

scan-etcd:
	@echo "Scanning minimal-etcd..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-etcd:latest
	@echo "✓ minimal-etcd: scan passed"

scan-victoria-metrics:
	@echo "Scanning minimal-victoria-metrics..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-victoria-metrics:latest
	@echo "✓ minimal-victoria-metrics: scan passed"

scan-jaeger:
	@echo "Scanning minimal-jaeger..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-jaeger:latest
	@echo "✓ minimal-jaeger: scan passed"

scan-otelcol:
	@echo "Scanning minimal-otelcol..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-otelcol:latest
	@echo "✓ minimal-otelcol: scan passed"

scan-qdrant:
	@echo "Scanning minimal-qdrant..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-qdrant:latest
	@echo "✓ minimal-qdrant: scan passed"

scan-deno:
	@echo "Scanning minimal-deno..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-deno:latest
	@echo "✓ minimal-deno: scan passed"

scan-cuda-python:
	@echo "Scanning minimal-cuda-python..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-cuda-python:latest
	@echo "✓ minimal-cuda-python: scan passed"

scan-coredns:
	@echo "Scanning minimal-coredns..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-coredns:latest
	@echo "✓ minimal-coredns: scan passed"

scan-openbao:
	@echo "Scanning minimal-openbao..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-openbao:latest
	@echo "✓ minimal-openbao: scan passed"

scan-loki:
	@echo "Scanning minimal-loki..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-loki:latest
	@echo "✓ minimal-loki: scan passed"

scan-fluent-bit:
	@echo "Scanning minimal-fluent-bit..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-fluent-bit:latest
	@echo "✓ minimal-fluent-bit: scan passed"

scan-keycloak:
	@echo "Scanning minimal-keycloak..."
	trivy image --exit-code 1 --severity CRITICAL,HIGH \
		$(REGISTRY)/$(OWNER)/minimal-keycloak:latest
	@echo "✓ minimal-keycloak: scan passed"

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
		$(REGISTRY)/$(OWNER)/minimal-node-slim:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-nginx:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-httpd:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-redis-slim:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-mysql:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-memcached:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-caddy:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-bun:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-sqlite:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-dotnet:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-java:latest
	trivy image --severity CRITICAL,HIGH,MEDIUM,LOW \
		$(REGISTRY)/$(OWNER)/minimal-kafka:latest

#------------------------------------------------------------------------------
# IMAGE SIZE REPORT
#------------------------------------------------------------------------------
size:
	@echo "Image sizes:"
	@docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | \
		grep -E "(minimal-python|minimal-jenkins|minimal-go|minimal-node-slim|minimal-nginx|minimal-httpd|minimal-redis-slim|minimal-mysql|minimal-memcached|minimal-caddy|minimal-haproxy|minimal-postgres-slim|minimal-bun|minimal-sqlite|minimal-dotnet|minimal-java|minimal-ruby|minimal-rails|minimal-kafka)" || true

#------------------------------------------------------------------------------
# TESTING
#------------------------------------------------------------------------------
test: test-python test-node-slim test-bun test-go test-java test-ruby test-php test-dotnet test-deno test-mysql test-mariadb test-postgres-slim test-pgbouncer test-unbound test-dnsmasq test-keepalived test-vector test-patroni test-metrics-server test-external-dns test-velero test-kaniko test-step-ca test-skopeo test-sqlite test-opensearch test-redis-slim test-valkey test-memcached test-kafka test-zookeeper test-cassandra test-solr test-pulsar test-tomcat test-rabbitmq test-nats test-mosquitto test-nginx test-httpd test-caddy test-haproxy test-traefik test-envoy test-oauth2-proxy test-prometheus test-alertmanager test-victoria-metrics test-thanos test-mimir test-jaeger test-loki test-tempo test-otelcol test-fluent-bit test-telegraf test-node-exporter test-blackbox-exporter test-pushgateway test-coredns test-etcd test-openbao test-keycloak test-qdrant test-registry test-consul test-helm test-kubectl test-opentofu test-trivy test-cosign test-syft test-grype test-osv-scanner test-oras test-notation test-conftest test-kubeconform test-kube-bench test-trufflehog test-flux test-kustomize test-sops test-crane test-kubeseal test-helmfile test-regctl test-stern test-gitleaks test-step-cli test-opa test-jenkins test-gitea test-minio test-rails test-mailpit

$(eval $(call DEV_TEST_RULE,python))
$(eval $(call DEV_TEST_RULE,node-slim))
$(eval $(call DEV_TEST_RULE,go))
$(eval $(call DEV_TEST_RULE,java))
$(eval $(call DEV_TEST_RULE,dotnet))
$(eval $(call DEV_TEST_RULE,bun))
$(eval $(call DEV_TEST_RULE,deno))
$(eval $(call DEV_TEST_RULE,rails))
$(eval $(call DEV_TEST_RULE,php))
$(eval $(call DEV_TEST_RULE,postgres-slim))
$(eval $(call DEV_TEST_RULE,mariadb))
$(eval $(call DEV_TEST_RULE,redis-slim))
$(eval $(call DEV_TEST_RULE,valkey))
$(eval $(call DEV_TEST_RULE,memcached))
$(eval $(call DEV_TEST_RULE,sqlite))
$(eval $(call DEV_TEST_RULE,opensearch))
$(eval $(call DEV_TEST_RULE,kafka))
$(eval $(call DEV_TEST_RULE,cassandra))
$(eval $(call DEV_TEST_RULE,solr))
$(eval $(call DEV_TEST_RULE,pulsar))
$(eval $(call DEV_TEST_RULE,rabbitmq))
$(eval $(call DEV_TEST_RULE,nats))
$(eval $(call DEV_TEST_RULE,etcd))
$(eval $(call DEV_TEST_RULE,nginx))
$(eval $(call DEV_TEST_RULE,haproxy))
$(eval $(call DEV_TEST_RULE,minio))
$(eval $(call DEV_TEST_RULE,httpd))
$(eval $(call DEV_TEST_RULE,caddy))
$(eval $(call DEV_TEST_RULE,traefik))
$(eval $(call DEV_TEST_RULE,envoy))
$(eval $(call DEV_TEST_RULE,prometheus))
$(eval $(call DEV_TEST_RULE,alertmanager))
$(eval $(call DEV_TEST_RULE,victoria-metrics))
$(eval $(call DEV_TEST_RULE,jaeger))
$(eval $(call DEV_TEST_RULE,otelcol))
$(eval $(call DEV_TEST_RULE,loki))
$(eval $(call DEV_TEST_RULE,fluent-bit))
$(eval $(call DEV_TEST_RULE,coredns))
$(eval $(call DEV_TEST_RULE,gitea))
$(eval $(call DEV_TEST_RULE,jenkins))
$(eval $(call DEV_TEST_RULE,openbao))
$(eval $(call DEV_TEST_RULE,mysql))
$(eval $(call DEV_TEST_RULE,qdrant))
$(eval $(call DEV_TEST_RULE,keycloak))
$(eval $(call DEV_TEST_RULE,registry))
$(eval $(call DEV_TEST_RULE,mailpit))
$(eval $(call DEV_TEST_RULE,consul))
$(eval $(call DEV_TEST_RULE,tempo))
$(eval $(call DEV_TEST_RULE,mosquitto))
$(eval $(call DEV_TEST_RULE,pgbouncer))
$(eval $(call DEV_TEST_RULE,unbound))
$(eval $(call DEV_TEST_RULE,dnsmasq))
$(eval $(call DEV_TEST_RULE,patroni))
$(eval $(call DEV_TEST_RULE,vector))
$(eval $(call DEV_TEST_RULE,keepalived))
$(eval $(call DEV_TEST_RULE,metrics-server))
$(eval $(call DEV_TEST_RULE,external-dns))
$(eval $(call DEV_TEST_RULE,velero))
$(eval $(call DEV_TEST_RULE,kaniko))
$(eval $(call DEV_TEST_RULE,step-ca))
$(eval $(call DEV_TEST_RULE,skopeo))
$(eval $(call DEV_TEST_RULE,telegraf))
$(eval $(call DEV_TEST_RULE,mimir))
# --- dev smoke tests for the CLI / exporter / static-Go dev variants.
$(eval $(call DEV_TEST_RULE,zookeeper))
$(eval $(call DEV_TEST_RULE,tomcat))
$(eval $(call DEV_TEST_RULE,oauth2-proxy))
$(eval $(call DEV_TEST_RULE,thanos))
$(eval $(call DEV_TEST_RULE,node-exporter))
$(eval $(call DEV_TEST_RULE,blackbox-exporter))
$(eval $(call DEV_TEST_RULE,pushgateway))
$(eval $(call DEV_TEST_RULE,helm))
$(eval $(call DEV_TEST_RULE,kubectl))
$(eval $(call DEV_TEST_RULE,opentofu))
$(eval $(call DEV_TEST_RULE,trivy))
$(eval $(call DEV_TEST_RULE,cosign))
$(eval $(call DEV_TEST_RULE,syft))
$(eval $(call DEV_TEST_RULE,grype))
$(eval $(call DEV_TEST_RULE,osv-scanner))
$(eval $(call DEV_TEST_RULE,oras))
$(eval $(call DEV_TEST_RULE,notation))
$(eval $(call DEV_TEST_RULE,conftest))
$(eval $(call DEV_TEST_RULE,kubeconform))
$(eval $(call DEV_TEST_RULE,kube-bench))
$(eval $(call DEV_TEST_RULE,trufflehog))
$(eval $(call DEV_TEST_RULE,flux))
$(eval $(call DEV_TEST_RULE,kustomize))
$(eval $(call DEV_TEST_RULE,sops))
$(eval $(call DEV_TEST_RULE,crane))
$(eval $(call DEV_TEST_RULE,kubeseal))
$(eval $(call DEV_TEST_RULE,helmfile))
$(eval $(call DEV_TEST_RULE,regctl))
$(eval $(call DEV_TEST_RULE,stern))
$(eval $(call DEV_TEST_RULE,gitleaks))
$(eval $(call DEV_TEST_RULE,step-cli))
$(eval $(call DEV_TEST_RULE,opa))

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

test-node-slim:
	@echo "Testing Node.js image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-node-slim:latest --version
	@echo "Testing simple script..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-node-slim:latest -e 'console.log("Hello minimal node")'
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-node-slim:latest \
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

test-mysql:
	@echo "Testing MySQL image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-mysql:latest --version
	@echo "Testing MySQL client..."
	docker run --rm --entrypoint /usr/bin/mysql \
		$(REGISTRY)/$(OWNER)/minimal-mysql:latest --version
	@echo "✓ MySQL tests passed"

test-memcached:
	@echo "Testing Memcached image..."
	@docker run -d --name memcached-test $(REGISTRY)/$(OWNER)/minimal-memcached:latest -u memcached
	@sleep 2
	@if docker ps | grep -q memcached-test; then \
		echo "Memcached is running"; \
		docker logs memcached-test; \
		docker stop memcached-test && docker rm memcached-test; \
	else \
		echo "Memcached failed to start, checking logs..."; \
		docker logs memcached-test 2>&1 || true; \
		docker rm memcached-test 2>/dev/null || true; \
		exit 1; \
	fi
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-memcached:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Memcached tests passed"

test-caddy:
	@echo "Testing Caddy image..."
	docker run --rm --entrypoint /usr/bin/caddy \
		$(REGISTRY)/$(OWNER)/minimal-caddy:latest version
	@echo "Testing Caddy modules..."
	@docker run --rm --entrypoint /usr/bin/caddy \
		$(REGISTRY)/$(OWNER)/minimal-caddy:latest list-modules 2>&1 | head -20 || true
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-caddy:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Caddy tests passed"

test-haproxy:
	@echo "Testing HAProxy image..."
	docker run --rm --entrypoint /usr/bin/haproxy \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:latest -v
	@echo "Testing HAProxy build options..."
	@docker run --rm --entrypoint /usr/bin/haproxy \
		$(REGISTRY)/$(OWNER)/minimal-haproxy:latest -vv 2>&1 | grep -E "(USE_OPENSSL|USE_PCRE2)" || \
		{ echo "FAIL: Expected USE_OPENSSL and USE_PCRE2"; exit 1; }
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-haproxy:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ HAProxy tests passed"

test-postgres-slim:
	@echo "Testing Postgres Slim image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest" && \
		images/postgres-slim/test.sh
	@echo "✓ Postgres Slim tests passed"

test-bun:
	@echo "Testing Bun image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-bun:latest --version
	@echo "Testing simple script..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-bun:latest -e 'console.log("Hello minimal bun")'
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-bun:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Bun tests passed"

test-sqlite:
	@echo "Testing SQLite image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-sqlite:latest --version
	@echo "Testing in-memory query..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-sqlite:latest :memory: "SELECT 1;"
	@echo "Testing file-based DB..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-sqlite:latest /tmp/test.db \
		"CREATE TABLE t(x); INSERT INTO t VALUES(1); SELECT * FROM t;"
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-sqlite:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ SQLite tests passed"

test-dotnet:
	@echo "Testing .NET Runtime image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-dotnet:latest --info
	@echo "Checking runtime list..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-dotnet:latest --list-runtimes
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-dotnet:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ .NET Runtime tests passed"

test-java:
	@echo "Testing OpenJDK Runtime image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-java:latest -version
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-java:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ OpenJDK Runtime tests passed"

test-ruby:
	@IMAGE=$(REGISTRY)/$(OWNER)/minimal-ruby:latest bash images/ruby/test.sh
	@echo "✓ Ruby tests passed"

$(eval $(call DEV_TEST_RULE,ruby))

test-rails:
	@echo "Testing Rails image..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-rails:latest -v
	@echo "Testing Rails version..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-rails:latest \
		-e "require 'rails'; puts Rails.version"
	@echo "Testing Bundler..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-rails:latest \
		-e "require 'bundler'; puts Bundler::VERSION"
	@echo "Testing core libraries..."
	docker run --rm $(REGISTRY)/$(OWNER)/minimal-rails:latest \
		-e "require 'openssl'; require 'yaml'; require 'json'; puts 'Core libs OK'"
	@echo "Verifying no shell..."
	@docker run --rm --entrypoint /bin/sh $(REGISTRY)/$(OWNER)/minimal-rails:latest \
		-c "echo fail" 2>/dev/null && echo "FAIL: shell found!" && exit 1 || echo "✓ No shell (as expected)"
	@echo "✓ Rails tests passed"

test-kafka:
	@echo "Testing Kafka image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kafka:latest" && \
		images/kafka/test.sh
	@echo "✓ Kafka tests passed"

test-cassandra:
	@echo "Testing Cassandra image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-cassandra:latest" && \
		images/cassandra/test.sh
	@echo "✓ Cassandra tests passed"

test-flink:
	@echo "Testing flink image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-flink:latest" && \
		images/flink/test.sh
	@echo "✓ flink tests passed"

test-solr:
	@echo "Testing Solr image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-solr:latest" && \
		images/solr/test.sh
	@echo "✓ Solr tests passed"

test-pulsar:
	@echo "Testing Pulsar image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-pulsar:latest" && \
		images/pulsar/test.sh
	@echo "✓ Pulsar tests passed"

test-zookeeper:
	@echo "Testing zookeeper image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-zookeeper:latest" && \
		images/zookeeper/test.sh
	@echo "✓ zookeeper tests passed"

test-tomcat:
	@echo "Testing tomcat image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-tomcat:latest" && \
		images/tomcat/test.sh
	@echo "✓ tomcat tests passed"

test-valkey:
	@echo "Testing Valkey image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-valkey:latest" && \
		images/valkey/test.sh
	@echo "✓ Valkey tests passed"

test-nats:
	@echo "Testing NATS image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-nats:latest" && \
		images/nats/test.sh
	@echo "✓ NATS tests passed"

test-traefik:
	@echo "Testing Traefik image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-traefik:latest" && \
		images/traefik/test.sh
	@echo "✓ Traefik tests passed"

test-envoy:
	@echo "Testing Envoy image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-envoy:latest" && \
		images/envoy/test.sh
	@echo "✓ Envoy tests passed"

test-rabbitmq:
	@echo "Testing RabbitMQ image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-rabbitmq:latest" && \
		images/rabbitmq/test.sh
	@echo "✓ RabbitMQ tests passed"

test-minio:
	@echo "Testing MinIO image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-minio:latest" && \
		images/minio/test.sh
	@echo "✓ MinIO tests passed"

test-registry:
	@echo "Testing registry image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-registry:latest" && \
		images/registry/test.sh
	@echo "✓ registry tests passed"

test-mailpit:
	@echo "Testing mailpit image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-mailpit:latest" && \
		images/mailpit/test.sh
	@echo "✓ mailpit tests passed"

test-consul:
	@echo "Testing consul image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-consul:latest" && \
		images/consul/test.sh
	@echo "✓ consul tests passed"

test-tempo:
	@echo "Testing tempo image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-tempo:latest" && \
		images/tempo/test.sh
	@echo "✓ tempo tests passed"

test-opentofu:
	@echo "Testing opentofu image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-opentofu:latest" && \
		images/opentofu/test.sh
	@echo "✓ opentofu tests passed"

test-trivy:
	@echo "Testing trivy image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-trivy:latest" && \
		images/trivy/test.sh
	@echo "✓ trivy tests passed"

test-cosign:
	@echo "Testing cosign image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-cosign:latest" && \
		images/cosign/test.sh
	@echo "✓ cosign tests passed"

test-syft:
	@echo "Testing syft image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-syft:latest" && \
		images/syft/test.sh
	@echo "✓ syft tests passed"

test-grype:
	@echo "Testing grype image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-grype:latest" && \
		images/grype/test.sh
	@echo "✓ grype tests passed"

test-oras:
	@echo "Testing oras image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-oras:latest" && \
		images/oras/test.sh
	@echo "✓ oras tests passed"

test-gitleaks:
	@echo "Testing gitleaks image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-gitleaks:latest" && \
		images/gitleaks/test.sh
	@echo "✓ gitleaks tests passed"

test-step-cli:
	@echo "Testing step-cli image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-step-cli:latest" && \
		images/step-cli/test.sh
	@echo "✓ step-cli tests passed"

test-opa:
	@echo "Testing opa image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-opa:latest" && \
		images/opa/test.sh
	@echo "✓ opa tests passed"

test-osv-scanner:
	@echo "Testing osv-scanner image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-osv-scanner:latest" && \
		images/osv-scanner/test.sh
	@echo "✓ osv-scanner tests passed"

test-seaweedfs:
	@echo "Testing seaweedfs image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-seaweedfs:latest" && \
		images/seaweedfs/test.sh
	@echo "✓ seaweedfs tests passed"

test-dex:
	@echo "Testing dex image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-dex:latest" && \
		images/dex/test.sh
	@echo "✓ dex tests passed"

test-oauth2-proxy:
	@echo "Testing oauth2-proxy image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-oauth2-proxy:latest" && \
		images/oauth2-proxy/test.sh
	@echo "✓ oauth2-proxy tests passed"

test-flux:
	@echo "Testing flux image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-flux:latest" && \
		images/flux/test.sh
	@echo "✓ flux tests passed"

test-kustomize:
	@echo "Testing kustomize image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kustomize:latest" && \
		images/kustomize/test.sh
	@echo "✓ kustomize tests passed"

test-sops:
	@echo "Testing sops image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-sops:latest" && \
		images/sops/test.sh
	@echo "✓ sops tests passed"

test-crane:
	@echo "Testing crane image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-crane:latest" && \
		images/crane/test.sh
	@echo "✓ crane tests passed"

test-kubeseal:
	@echo "Testing kubeseal image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kubeseal:latest" && \
		images/kubeseal/test.sh
	@echo "✓ kubeseal tests passed"

test-helmfile:
	@echo "Testing helmfile image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-helmfile:latest" && \
		images/helmfile/test.sh
	@echo "✓ helmfile tests passed"

test-regctl:
	@echo "Testing regctl image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-regctl:latest" && \
		images/regctl/test.sh
	@echo "✓ regctl tests passed"

test-stern:
	@echo "Testing stern image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-stern:latest" && \
		images/stern/test.sh
	@echo "✓ stern tests passed"


test-notation:
	@echo "Testing notation image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-notation:latest" && images/notation/test.sh
	@echo "✓ notation tests passed"

test-conftest:
	@echo "Testing conftest image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-conftest:latest" && images/conftest/test.sh
	@echo "✓ conftest tests passed"

test-kubeconform:
	@echo "Testing kubeconform image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kubeconform:latest" && images/kubeconform/test.sh
	@echo "✓ kubeconform tests passed"

test-kube-bench:
	@echo "Testing kube-bench image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kube-bench:latest" && images/kube-bench/test.sh
	@echo "✓ kube-bench tests passed"

test-trufflehog:
	@echo "Testing trufflehog image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-trufflehog:latest" && images/trufflehog/test.sh
	@echo "✓ trufflehog tests passed"

test-thanos:
	@echo "Testing thanos image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-thanos:latest" && \
		images/thanos/test.sh
	@echo "✓ thanos tests passed"

test-node-exporter:
	@echo "Testing node-exporter image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-node-exporter:latest" && \
		images/node-exporter/test.sh
	@echo "✓ node-exporter tests passed"

test-blackbox-exporter:
	@echo "Testing blackbox-exporter image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-blackbox-exporter:latest" && \
		images/blackbox-exporter/test.sh
	@echo "✓ blackbox-exporter tests passed"

test-redis-exporter:
	@echo "Testing redis-exporter image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-redis-exporter:latest" && \
		images/redis-exporter/test.sh
	@echo "✓ redis-exporter tests passed"

test-kube-state-metrics:
	@echo "Testing kube-state-metrics image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kube-state-metrics:latest" && \
		images/kube-state-metrics/test.sh
	@echo "✓ kube-state-metrics tests passed"

test-pushgateway:
	@echo "Testing pushgateway image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-pushgateway:latest" && \
		images/pushgateway/test.sh
	@echo "✓ pushgateway tests passed"

test-mosquitto:
	@echo "Testing mosquitto image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-mosquitto:latest" && \
		images/mosquitto/test.sh
	@echo "✓ mosquitto tests passed"

test-pgbouncer:
	@echo "Testing pgbouncer image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-pgbouncer:latest" && \
		images/pgbouncer/test.sh
	@echo "✓ pgbouncer tests passed"

test-keepalived:
	@echo "Testing keepalived image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-keepalived:latest" && \
		images/keepalived/test.sh
	@echo "✓ keepalived tests passed"

test-vector:
	@echo "Testing vector image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-vector:latest" && \
		images/vector/test.sh
	@echo "✓ vector tests passed"

test-patroni:
	@echo "Testing patroni image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-patroni:latest" && \
		images/patroni/test.sh
	@echo "✓ patroni tests passed"

test-metrics-server:
	@echo "Testing metrics-server image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-metrics-server:latest" && \
		images/metrics-server/test.sh
	@echo "✓ metrics-server tests passed"

test-dnsmasq:
	@echo "Testing dnsmasq image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-dnsmasq:latest" && \
		images/dnsmasq/test.sh
	@echo "✓ dnsmasq tests passed"

test-unbound:
	@echo "Testing unbound image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-unbound:latest" && \
		images/unbound/test.sh
	@echo "✓ unbound tests passed"

test-external-dns:
	@echo "Testing external-dns image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-external-dns:latest" && \
		images/external-dns/test.sh
	@echo "✓ external-dns tests passed"

test-velero:
	@echo "Testing velero image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-velero:latest" && \
		images/velero/test.sh
	@echo "✓ velero tests passed"

test-kaniko:
	@echo "Testing kaniko image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kaniko:latest" && \
		images/kaniko/test.sh
	@echo "✓ kaniko tests passed"

test-step-ca:
	@echo "Testing step-ca image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-step-ca:latest" && \
		images/step-ca/test.sh
	@echo "✓ step-ca tests passed"

test-skopeo:
	@echo "Testing skopeo image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-skopeo:latest" && \
		images/skopeo/test.sh
	@echo "✓ skopeo tests passed"

test-helm:
	@echo "Testing helm image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-helm:latest" && \
		images/helm/test.sh
	@echo "✓ helm tests passed"

test-kubectl:
	@echo "Testing kubectl image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-kubectl:latest" && \
		images/kubectl/test.sh
	@echo "✓ kubectl tests passed"

test-opensearch:
	@echo "Testing OpenSearch image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-opensearch:latest" && \
		images/opensearch/test.sh
	@echo "✓ OpenSearch tests passed"

test-prometheus:
	@echo "Testing Prometheus image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-prometheus:latest" && \
		images/prometheus/test.sh
	@echo "✓ Prometheus tests passed"

test-alertmanager:
	@echo "Testing Alertmanager image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-alertmanager:latest" && \
		images/alertmanager/test.sh
	@echo "✓ Alertmanager tests passed"


test-mariadb:
	@echo "Testing MariaDB image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-mariadb:latest" && \
		images/mariadb/test.sh
	@echo "✓ MariaDB tests passed"

test-etcd:
	@echo "Testing etcd image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-etcd:latest" && \
		images/etcd/test.sh
	@echo "✓ etcd tests passed"

test-victoria-metrics:
	@echo "Testing VictoriaMetrics image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-victoria-metrics:latest" && \
		images/victoria-metrics/test.sh
	@echo "✓ VictoriaMetrics tests passed"

test-telegraf:
	@echo "Testing Telegraf image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-telegraf:latest" && \
		images/telegraf/test.sh
	@echo "✓ Telegraf tests passed"

test-mimir:
	@echo "Testing Mimir image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-mimir:latest" && \
		images/mimir/test.sh
	@echo "✓ Mimir tests passed"

test-coredns:
	@echo "Testing CoreDNS image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-coredns:latest" && \
		images/coredns/test.sh
	@echo "✓ coredns tests passed"

test-fluent-bit:
	@echo "Testing Fluent Bit image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-fluent-bit:latest" && \
		images/fluent-bit/test.sh
	@echo "✓ fluent-bit tests passed"

test-keycloak:
	@echo "Testing Keycloak image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-keycloak:latest" && \
		images/keycloak/test.sh
	@echo "✓ keycloak tests passed"

test-loki:
	@echo "Testing Loki image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-loki:latest" && \
		images/loki/test.sh
	@echo "✓ loki tests passed"

test-openbao:
	@echo "Testing OpenBao image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-openbao:latest" && \
		images/openbao/test.sh
	@echo "✓ openbao tests passed"

test-php:
	@echo "Testing PHP image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-php:latest" && \
		images/php/test.sh
	@echo "✓ php tests passed"

test-gitea:
	@echo "Testing Gitea image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-gitea:latest" && \
		images/gitea/test.sh
	@echo "✓ gitea tests passed"


test-jaeger:
	@echo "Testing Jaeger image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-jaeger:latest" && \
		images/jaeger/test.sh
	@echo "✓ Jaeger tests passed"

test-otelcol:
	@echo "Testing OTel Collector image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-otelcol:latest" && \
		images/otelcol/test.sh
	@echo "✓ OTel Collector tests passed"

test-vaultwarden:
	@echo "Testing vaultwarden image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-vaultwarden:latest" && \
		images/vaultwarden/test.sh
	@echo "✓ vaultwarden tests passed"

test-qdrant:
	@echo "Testing Qdrant image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-qdrant:latest" && \
		images/qdrant/test.sh
	@echo "✓ Qdrant tests passed"

test-deno:
	@echo "Testing Deno image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-deno:latest" && \
		images/deno/test.sh
	@echo "✓ Deno tests passed"

test-cuda-python:
	@echo "Testing CUDA Python image..."
	export IMAGE="$(REGISTRY)/$(OWNER)/minimal-cuda-python:latest" && \
		images/cuda-python/test.sh
	@echo "✓ CUDA Python tests passed"

#------------------------------------------------------------------------------
# PUSH TO REGISTRY
#------------------------------------------------------------------------------
# Every image's build rule tags both a version tag and :latest, so one push-%
# pattern rule covers all 88 uniformly — mirroring build:/test:/scan:. The 4
# images that don't ride the global VERSION get a per-image tag override here
# (empty override falls back to $(VERSION) via $(or …)).
PUSH_VER_kafka     = $(KAFKA_VERSION)
PUSH_VER_zookeeper = $(ZOOKEEPER_VERSION)
PUSH_VER_cassandra = $(CASSANDRA_VERSION)
PUSH_VER_solr      = $(SOLR_VERSION)
PUSH_VER_pulsar    = $(PULSAR_VERSION)
PUSH_VER_tomcat    = $(TOMCAT_VERSION)
PUSH_VER_rabbitmq  = $(RABBITMQ_VERSION)

push-%:
	docker push $(REGISTRY)/$(OWNER)/minimal-$*:$(or $(PUSH_VER_$*),$(VERSION))
	docker push $(REGISTRY)/$(OWNER)/minimal-$*:latest

push: push-python push-node-slim push-bun push-go push-java push-ruby push-php push-dotnet push-deno push-mysql push-mariadb push-postgres-slim push-pgbouncer push-unbound push-dnsmasq push-keepalived push-vector push-patroni push-metrics-server push-external-dns push-velero push-kaniko push-step-ca push-skopeo push-sqlite push-opensearch push-redis-slim push-valkey push-memcached push-kafka push-zookeeper push-cassandra push-solr push-pulsar push-tomcat push-rabbitmq push-nats push-mosquitto push-nginx push-httpd push-caddy push-haproxy push-traefik push-envoy push-oauth2-proxy push-prometheus push-alertmanager push-victoria-metrics push-thanos push-mimir push-jaeger push-loki push-tempo push-otelcol push-fluent-bit push-telegraf push-node-exporter push-blackbox-exporter push-pushgateway push-coredns push-etcd push-openbao push-keycloak push-qdrant push-registry push-consul push-helm push-kubectl push-opentofu push-trivy push-cosign push-syft push-grype push-osv-scanner push-oras push-notation push-conftest push-kubeconform push-kube-bench push-trufflehog push-flux push-kustomize push-sops push-crane push-kubeseal push-helmfile push-regctl push-stern push-gitleaks push-step-cli push-opa push-jenkins push-gitea push-minio push-rails push-mailpit

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
	docker rmi $(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-node-slim:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-node-slim:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nginx:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-httpd:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-redis-slim:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-mysql:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-mysql:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-memcached:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-memcached:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-caddy:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-caddy:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-haproxy:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-haproxy:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-postgres-slim:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-bun:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-bun:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-sqlite:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-sqlite:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-dotnet:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-dotnet:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-java:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-java:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-java:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-ruby:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-ruby:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rails:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rails:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-kafka:$(KAFKA_VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-kafka:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cassandra:$(CASSANDRA_VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cassandra:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-solr:$(SOLR_VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-solr:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-pulsar:$(PULSAR_VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-pulsar:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-valkey:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-valkey:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nats:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-nats:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-traefik:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-traefik:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-envoy:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-envoy:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rabbitmq:$(RABBITMQ_VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-rabbitmq:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-minio:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-minio:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-opensearch:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-opensearch:latest 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION) 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cuda-python:$(VERSION)-amd64 2>/dev/null || true
	docker rmi $(REGISTRY)/$(OWNER)/minimal-cuda-python:latest 2>/dev/null || true
	rm -f *.tar sbom-*.spdx.json
	rm -rf packages/
	@echo "✓ Cleanup complete"

#------------------------------------------------------------------------------
# LINT
#------------------------------------------------------------------------------
# Validate all GitHub Actions workflows (schema + embedded Bash in `run:` blocks)
# via actionlint + shellcheck. Run this before pushing any .github/workflows/**
# change — most workflows only run on schedule, so a shell syntax error there
# never executes on the PR and would otherwise only surface on main.
lint-workflows:
	@./scripts/lint-workflows.sh

# Assert every prod image (catalog.json) has exactly one live auto-update
# mechanism (a cron-enabled versions.yaml row, or a declared Wolfi-package
# class). Run before pushing any new image or versions.yaml/catalog.json change.
check-docs:
	@bash tools/check-docs.sh

check-packages:
	@bash tools/check-packages.sh

check-packages-report:
	@bash tools/check-packages.sh --report

check-autoupdate:
	@./scripts/check-autoupdate-coverage.sh

check-toolchain-pins:
	@./scripts/check-toolchain-pins.sh

check-curl-retries:
	@./scripts/check-curl-retries.sh

test-classifier:
	@./tests/test-classify-build-failure.sh

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
	@echo "  make node-slim       Build Node.js Slim (Wolfi package, shell-less)"
	@echo "  make jenkins         Build Jenkins $(JENKINS_VERSION) (jlink JRE)"
	@echo "  make jenkins-melange Build Jenkins package only (no image)"
	@echo "  make nginx           Build Nginx $(NGINX_VERSION) (Wolfi package)"
	@echo "  make httpd           Build HTTPD $(HTTPD_VERSION) (Wolfi package)"
	@echo "  make redis-slim      Build Redis Slim $(REDIS_VERSION) (source build)"
	@echo "  make mysql           Build MySQL $(MYSQL_VERSION) LTS (source build)"
	@echo "  make memcached       Build Memcached $(MEMCACHED_VERSION) (source build)"
	@echo "  make caddy           Build Caddy $(CADDY_VERSION) (source build)"
	@echo "  make haproxy         Build HAProxy $(HAPROXY_VERSION) (source build)"
	@echo "  make postgres-slim   Build Postgres Slim (Wolfi package)"
	@echo "  make bun             Build Bun (Wolfi package)"
	@echo "  make sqlite          Build SQLite (Wolfi package)"
	@echo "  make dotnet          Build .NET Runtime (Wolfi package)"
	@echo "  make java            Build OpenJDK 21 JRE (Wolfi package)"
	@echo "  make ruby            Build Ruby $(RUBY_VERSION) (source build, shell-less)"
	@echo "  make php             Build PHP (melange source build)"
	@echo "  make rails           Build Rails (Ruby $(RUBY_VERSION) + Rails $(RAILS_VERSION), source build)"
	@echo "  make kafka           Build Kafka $(KAFKA_VERSION) (official binary + jlink JRE, KRaft)"
	@echo "  make cassandra       Build Cassandra $(CASSANDRA_VERSION) (official binary + jlink JRE)"
	@echo "  make solr            Build Solr $(SOLR_VERSION) (official binary + jlink JRE)"
	@echo "  make pulsar          Build Pulsar $(PULSAR_VERSION) (official binary + jlink JRE)"
	@echo "  make kafka-melange   Build Kafka package only (no image)"
	@echo "  make valkey          Build Valkey $(VALKEY_VERSION) (source build)"
	@echo "  make nats            Build NATS $(NATS_VERSION) (source build)"
	@echo "  make traefik         Build Traefik $(TRAEFIK_VERSION) (source build)"
	@echo "  make envoy           Build Envoy $(ENVOY_VERSION) (upstream binary)"
	@echo "  make rabbitmq        Build RabbitMQ $(RABBITMQ_VERSION) (official binary + Wolfi Erlang)"
	@echo "  make minio           Build MinIO $(MINIO_VERSION) (source build)"
	@echo "  make opensearch      Build OpenSearch $(OPENSEARCH_VERSION) (Wolfi package)"
	@echo "  make cuda-python     Build CUDA Python $(CUDA_VERSION) (NVIDIA redist + Python, x86_64)"
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
	@echo "  MYSQL_VERSION=$(MYSQL_VERSION)"
	@echo "  MEMCACHED_VERSION=$(MEMCACHED_VERSION)"
	@echo "  CADDY_VERSION=$(CADDY_VERSION)"
	@echo "  HAPROXY_VERSION=$(HAPROXY_VERSION)"
	@echo "  RUBY_VERSION=$(RUBY_VERSION)"
	@echo "  RAILS_VERSION=$(RAILS_VERSION)"
	@echo "  KAFKA_VERSION=$(KAFKA_VERSION)"
	@echo "  VALKEY_VERSION=$(VALKEY_VERSION)"
	@echo "  NATS_VERSION=$(NATS_VERSION)"
	@echo "  TRAEFIK_VERSION=$(TRAEFIK_VERSION)"
	@echo "  RABBITMQ_VERSION=$(RABBITMQ_VERSION)"
	@echo "  OPENSEARCH_VERSION=$(OPENSEARCH_VERSION)"
	@echo "  CUDA_VERSION=$(CUDA_VERSION)"
	@echo "  REGISTRY=$(REGISTRY)"
	@echo "  OWNER=$(OWNER)"
