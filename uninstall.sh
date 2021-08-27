set -e

helm uninstall --kube-context $1 -n centralized-logging elasticsearch
helm uninstall --kube-context $1 -n centralized-logging kibana
helm uninstall --kube-context $1 -n centralized-logging fluent-bit
helm uninstall --kube-context $1 -n centralized-logging apm-server
helm uninstall --kube-context $1 -n centralized-logging elastichq