# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.


#########################
## LB
#########################
output "lb" {
  description = "The returned resource attributes for the LB."
  value       = oci_load_balancer_load_balancer.this
}

output "lb_protocols" {
  description = "The available protocols."
  value       = data.oci_load_balancer_protocols.this
}

output "lb_shapes" {
  description = "Available LB shapes."
  value       = data.oci_load_balancer_shapes.this
}

output "certificates" {
  description = "Certificates created/managed."
  value       = {
    for x in oci_load_balancer_certificate.this:
      x.certificate_name => x
  }
}

output "backend_sets" {
  description = "All of the Backend Sets created/managed."
  value       = merge(
    {
      for x in oci_load_balancer_backend_set.this_no_persistency_no_ssl:
        x.name => merge( x, { backends = [ for i in oci_load_balancer_backend.this : i if i.backendset_name == x.name ] } )
    },
    {
      for x in oci_load_balancer_backend_set.this_no_persistency_ssl:
        x.name => merge( x, { backends = [ for i in oci_load_balancer_backend.this : i if i.backendset_name == x.name ] } )
    },
    {
      for x in oci_load_balancer_backend_set.this_persistency_no_ssl:
        x.name => merge( x, { backends = [ for i in oci_load_balancer_backend.this : i if i.backendset_name == x.name ] } )
    },
    {
      for x in oci_load_balancer_backend_set.this_persistency_ssl:
        # x.name => x
        x.name => merge( x, { backends = [ for i in oci_load_balancer_backend.this : i if i.backendset_name == x.name ] } )
    }
  )
}

output "backends" {
  description = "Backends created/managed."
  value       = {
    for x in oci_load_balancer_backend.this:
      "${x.backendset_name}_${x.ip_address}_${x.port}" => x
  }
}

output "path_route_sets" {
  description = "Path Route Sets created/managed."
  value       = {
    for x in oci_load_balancer_path_route_set.this:
      x.name => x
  }
}

output "rule_sets" {
  description = "Rule Sets created/managed."
  value       = {
    for x in oci_load_balancer_rule_set.this:
      x.name => x
  }
}

output "listeners" {
  description = "All of the Listeners created/managed."
  value       = merge(
    {
      for x in oci_load_balancer_listener.this_no_ssl:
        x.name => merge( x, { hostnames = concat( [ for i in oci_load_balancer_hostname.this : i.hostname if i.name == "${x.name}_${i.hostname}" ] ) } )
    },
    {
      for x in oci_load_balancer_listener.this_ssl:
        x.name => merge( x, { hostnames = concat( [ for i in oci_load_balancer_hostname.this : i.hostname if i.name == "${x.name}_${i.hostname}" ] ) } )
    }
  )
}

output "hostnames" {
  description = "Hostnames created/managed."
  value       = {
    for x in oci_load_balancer_hostname.this:
      x.name => x
  }
}
