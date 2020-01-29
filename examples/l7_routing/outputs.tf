# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.


output "lb" {
  description = "LB"
  value       = module.oci_lb.lb
}

output "backend_sets" {
  value       = module.oci_lb.backend_sets
}

output "listeners" {
  value       = module.oci_lb.listeners
}