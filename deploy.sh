set -e

helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

helm upgrade --kube-context $1 -f elasticsearch-values.yml --create-namespace -n centralized-logging -i --wait --timeout 240s elasticsearch elastic/elasticsearch
helm upgrade --kube-context $1 -f kibana-values.yml --create-namespace -n centralized-logging -i --wait --timeout 240s kibana elastic/kibana
helm upgrade --kube-context $1 -f fluent-bit-values.yml --create-namespace -n centralized-logging -i --wait --timeout 20s fluent-bit fluent/fluent-bit
helm upgrade --kube-context $1 -f apm-values.yaml --create-namespace -n centralized-logging -i --wait --timeout 240s apm-server elastic/apm-server
helm upgrade --kube-context $1 -f metricbeat-values.yml -i -n kube-system metricbeat elastic/metricbeat
helm upgrade --kube-context $1 -f elastichq-values.yaml -i -n kube-system elastichq onemrva/elastichq
