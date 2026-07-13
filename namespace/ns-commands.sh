# imperative commands to create a pod in a specific namespace
k create -f pod-definition.yaml -n dev

# declarative commands to create a pod in a specific namespace (namespace is defined in the pod-definition.yaml file)
k apply -f pod-definition.yaml
# create namespace using imperative command
k create ns dev

# create ns using declarative command
k apply -f ns-definition.yaml

# set the default namespace for kubectl commands
k config set-context --current --namespace=dev
k config set-context $(k config current-context) --namespace=dev

# get current namespace
k config view | grep namespace: