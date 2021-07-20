set -e

helm

helm repo add elastic https://helm.elastic.co
helm repo update

helm upgrade -f elasticsearch-values.yml --create-namespace -n centralized-logging -i elasticsearch elastic/elasticsearch
helm upgrade -f kibana-values.yml --create-namespace -n centralized-logging -i kibana elastic/kibana
