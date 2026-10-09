package kubernetes.admission

# Deny privileged containers in banking workloads
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Privileged container not allowed: %v", [container.name])
}

# Require memory limits to prevent host node starvation
deny[msg] {
  input.request.kind.kind == "Pod"
  container := input.request.object.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Memory limit required: %v", [container.name])
}

# Require non-root execution
deny[msg] {
  input.request.kind.kind == "Pod"
  not input.request.object.spec.securityContext.runAsNonRoot == true
  msg := sprintf("Pod must specify runAsNonRoot: true")
}
