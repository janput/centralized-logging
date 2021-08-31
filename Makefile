default: help

STACK_VERSION := 7.14.0
CHART_VERSION := v$(STACK_VERSION)
TIMEOUT := 900s
ELASTICSEARCH_IMAGE := docker.elastic.co/elasticsearch/elasticsearch:$(STACK_VERSION)
NAMESPACE := efk-test

.PHONY: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

install:
	helm repo add elastic https://helm.elastic.co
	helm repo add fluent https://fluent.github.io/helm-charts
	helm repo update
	kubectl create namespace $(NAMESPACE) || true
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace $(NAMESPACE) --values elasticsearch-values.yml elasticsearch elastic/elasticsearch --version $(CHART_VERSION)
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace $(NAMESPACE) --values kibana-values.yml kibana elastic/kibana --version $(CHART_VERSION)
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace $(NAMESPACE) --values apm-values.yml apm-server elastic/apm-server --version $(CHART_VERSION)
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace $(NAMESPACE) --values fluent-bit.yml fluent-bit fluent/fluent-bit
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace $(NAMESPACE) --values elastichq-values.yml elastichq onemrva/elastichq
	helm upgrade --wait --timeout=$(TIMEOUT) --install --namespace kube-system --values metricbeat-values.yml metricbeat elastic/metricbeat --version $(CHART_VERSION)
	
purge:
	kubectl delete secrets elastic-credentials elastic-certificates elastic-certificate-pem elastic-certificate-crt || true
	kubectl delete secret kibana || true
	helm del --namespace kube-system metricbeat || true
	helm del --namespace $(NAMESPACE) elastichq || true
	helm del --namespace $(NAMESPACE) fluent-bit || true
	helm del --namespace $(NAMESPACE) apm-server || true
	helm del --namespace $(NAMESPACE) kibana || true
	helm del --namespace $(NAMESPACE) elasticsearch || true
	

pull-elasticsearch-image:
	docker pull $(ELASTICSEARCH_IMAGE)

secrets:
	docker rm -f elastic-helm-charts-certs || true
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12 || true
	password=$$([ ! -z "$$ELASTIC_PASSWORD" ] && echo $$ELASTIC_PASSWORD || echo $$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -cd '[:alnum:]' | head -c20")) && \
	docker run --name elastic-helm-charts-certs -i -w /app \
		$(ELASTICSEARCH_IMAGE) \
		/bin/sh -c " \
			elasticsearch-certutil ca --out /app/elastic-stack-ca.p12 --pass '' && \
			elasticsearch-certutil cert --name security-master --dns security-master --ca /app/elastic-stack-ca.p12 --pass '' --ca-pass '' --out /app/elastic-certificates.p12" && \
	docker cp elastic-helm-charts-certs:/app/elastic-certificates.p12 ./ && \
	docker rm -f elastic-helm-charts-certs && \
	openssl pkcs12 -nodes -passin pass:'' -in elastic-certificates.p12 -out elastic-certificate.pem && \
	openssl x509 -outform der -in elastic-certificate.pem -out elastic-certificate.crt && \
	kubectl create secret generic elastic-certificates --from-file=elastic-certificates.p12 && \
	kubectl create secret generic elastic-certificate-pem --from-file=elastic-certificate.pem && \
	kubectl create secret generic elastic-certificate-crt --from-file=elastic-certificate.crt && \
	kubectl create secret generic elastic-credentials --from-literal=password=$$password --from-literal=username=elastic && \
	rm -f elastic-certificates.p12 elastic-certificate.pem elastic-certificate.crt elastic-stack-ca.p12

secrets-kibana:
	encryptionkey=$$(docker run --rm busybox:1.31.1 /bin/sh -c "< /dev/urandom tr -dc _A-Za-z0-9 | head -c50") && \
	kubectl create secret generic kibana --from-literal=encryptionkey=$$encryptionkey