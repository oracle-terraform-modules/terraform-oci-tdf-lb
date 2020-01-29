# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

#################
# LB
#################
# default values
locals {
  lb_options_defaults = {
    display_name   = "lb"
    compartment_id = null
    shape          = data.oci_load_balancer_shapes.this.shapes[0].name
    subnet_ids     = null
    private        = true
    nsg_ids        = []
    defined_tags   = {}
    freeform_tags  = {}
  }
}

# resource definition
resource "oci_load_balancer_load_balancer" "this" {
  count          = var.lb_options == null ? 0 : length(var.lb_options) > 0 ? 1 : 0
  compartment_id = var.lb_options.compartment_id != null ? var.lb_options.compartment_id : var.default_compartment_id
  display_name   = var.lb_options.display_name != null ? var.lb_options.display_name : local.lb_options_defaults.display_name
  shape          = var.lb_options.shape != null ? var.lb_options.shape : local.lb_options_defaults.shape
  # can't really provide a default value here, so no need for additional logic (subnets must be user-defined)
  subnet_ids                 = var.lb_options.subnet_ids
  is_private                 = var.lb_options.private != null ? var.lb_options.private : local.lb_options_defaults.private
  network_security_group_ids = var.lb_options.nsg_ids != null ? var.lb_options.nsg_ids : local.lb_options_defaults.nsg_ids
  defined_tags               = var.lb_options.defined_tags != null ? var.lb_options.defined_tags : local.lb_options_defaults.defined_tags
  freeform_tags              = var.lb_options.freeform_tags != null ? var.lb_options.freeform_tags : local.lb_options_defaults.freeform_tags
}

#################
# Certificates
#################
# default values
locals {
  certificates_defaults = {
    name               = "certificate_"
    ca_certificate     = null
    passphrase         = null
    private_key        = null
    public_certificate = null
  }
  certificates_keys = keys(var.certificates)
}

# resource definition
resource "oci_load_balancer_certificate" "this" {
  count = length(local.certificates_keys)

  load_balancer_id   = oci_load_balancer_load_balancer.this[0].id
  certificate_name   = local.certificates_keys[count.index] != null ? local.certificates_keys[count.index] : "${local.certificates_defaults.name}${count.index}"
  ca_certificate     = var.certificates[local.certificates_keys[count.index]].ca_certificate != null ? var.certificates[local.certificates_keys[count.index]].ca_certificate : local.certificates_defaults.ca_certificate
  passphrase         = var.certificates[local.certificates_keys[count.index]].passphrase != null ? var.certificates[local.certificates_keys[count.index]].passphrase : local.certificates_defaults.passphrase
  private_key        = var.certificates[local.certificates_keys[count.index]].private_key != null ? var.certificates[local.certificates_keys[count.index]].private_key : local.certificates_defaults.private_key
  public_certificate = var.certificates[local.certificates_keys[count.index]].public_certificate != null ? var.certificates[local.certificates_keys[count.index]].public_certificate : local.certificates_defaults.public_certificate

  lifecycle {
    create_before_destroy = true
  }
}

#################
# Backend Sets
#################
# default values
locals {
  backend_sets_defaults = {
    name                    = "backend_set_"
    policy                  = data.oci_load_balancer_policies.this.policies[0].name
    health_check_name       = null
    enable_persistency      = true
    cookie_name             = "'*'"
    disable_fallback        = false
    enable_ssl              = false
    certificate_name        = null
    verify_depth            = 3
    verify_peer_certificate = true
  }
  health_check_defaults = {
    protocol            = data.oci_load_balancer_protocols.this.protocols[0].name
    interval_ms         = 1000
    port                = 443
    response_body_regex = ".*"
    retries             = 3
    return_code         = 200
    timeout_in_millis   = 3000
    url_path            = "/"
  }
  backend_sets_keys = keys(var.backend_sets)
  bes_min = { for k, v in var.backend_sets :
    k => {
      name              = k
      policy            = v.policy
      health_check_name = v.health_check_name
    } if v.enable_persistency != true && v.enable_ssl != true
  }
  bes_min_keys = keys(local.bes_min)
  bes_persistent = { for k, v in var.backend_sets :
    k => {
      name              = k
      policy            = v.policy
      health_check_name = v.health_check_name
      cookie_name       = v.cookie_name
      disable_fallback  = v.disable_fallback
    } if v.enable_persistency == true && v.enable_ssl != true
  }
  bes_persistent_keys = keys(local.bes_persistent)
  bes_persistent_ssl = { for k, v in var.backend_sets :
    k => {
      name                    = k
      policy                  = v.policy
      health_check_name       = v.health_check_name
      cookie_name             = v.cookie_name
      disable_fallback        = v.disable_fallback
      certificate_name        = v.certificate_name
      verify_depth            = v.verify_depth
      verify_peer_certificate = v.verify_peer_certificate
    } if v.enable_persistency == true && v.enable_ssl == true
  }
  bes_persistent_ssl_keys = keys(local.bes_persistent_ssl)
  bes_ssl = { for k, v in var.backend_sets :
    k => {
      name                    = k
      policy                  = v.policy
      health_check_name       = v.health_check_name
      certificate_name        = v.certificate_name
      verify_depth            = v.verify_depth
      verify_peer_certificate = v.verify_peer_certificate
    } if v.enable_persistency != true && v.enable_ssl == true
  }
  bes_ssl_keys = keys(local.bes_ssl)
}

# resource definition

# lb - no persistency, no SSL
resource "oci_load_balancer_backend_set" "this_no_persistency_no_ssl" {
  count = length(local.bes_min_keys)

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.bes_min_keys[count.index] != null ? local.bes_min_keys[count.index] : "${local.backend_sets_defaults.name}${count.index}"
  policy           = local.bes_min[local.bes_min_keys[count.index]] != null ? (local.bes_min[local.bes_min_keys[count.index]].policy != null ? local.bes_min[local.bes_min_keys[count.index]].policy : local.backend_sets_defaults.policy) : local.backend_sets_defaults.policy

  health_checker {
    protocol            = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].protocol : local.health_check_defaults.protocol
    interval_ms         = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].interval_ms : local.health_check_defaults.interval_ms
    port                = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].port : local.health_check_defaults.port
    response_body_regex = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].response_body_regex : local.health_check_defaults.response_body_regex
    retries             = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].retries : local.health_check_defaults.retries
    return_code         = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].return_code : local.health_check_defaults.return_code
    timeout_in_millis   = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].timeout_in_millis : local.health_check_defaults.timeout_in_millis
    url_path            = var.backend_sets[local.bes_min_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_min_keys[count.index]].health_check_name].url_path : local.health_check_defaults.url_path
  }
}

# lb - persistency, no SSL
resource "oci_load_balancer_backend_set" "this_persistency_no_ssl" {
  count = length(local.bes_persistent_keys)

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.bes_persistent_keys[count.index] != null ? local.bes_persistent_keys[count.index] : "${local.backend_sets_defaults.name}${count.index}"
  policy           = local.bes_persistent[local.bes_persistent_keys[count.index]] != null ? (local.bes_persistent[local.bes_persistent_keys[count.index]].policy != null ? local.bes_persistent[local.bes_persistent_keys[count.index]].policy : local.backend_sets_defaults.policy) : local.backend_sets_defaults.policy

  health_checker {
    protocol            = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].protocol : local.health_check_defaults.protocol
    interval_ms         = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].interval_ms : local.health_check_defaults.interval_ms
    port                = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].port : local.health_check_defaults.port
    response_body_regex = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].response_body_regex : local.health_check_defaults.response_body_regex
    retries             = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].retries : local.health_check_defaults.retries
    return_code         = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].return_code : local.health_check_defaults.return_code
    timeout_in_millis   = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].timeout_in_millis : local.health_check_defaults.timeout_in_millis
    url_path            = var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_keys[count.index]].health_check_name].url_path : local.health_check_defaults.url_path
  }

  session_persistence_configuration {
    cookie_name      = var.backend_sets[local.bes_persistent_keys[count.index]].cookie_name != null ? var.backend_sets[local.bes_persistent_keys[count.index]].cookie_name : local.backend_sets_defaults.cookie_name
    disable_fallback = var.backend_sets[local.bes_persistent_keys[count.index]].disable_fallback != null ? var.backend_sets[local.bes_persistent_keys[count.index]].disable_fallback : local.backend_sets_defaults.disable_fallback
  }
}

# lb - persistency, SSL
resource "oci_load_balancer_backend_set" "this_persistency_ssl" {
  count      = length(local.bes_persistent_ssl_keys)
  depends_on = [oci_load_balancer_certificate.this]

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.bes_persistent_ssl_keys[count.index] != null ? local.bes_persistent_ssl_keys[count.index] : "${local.backend_sets_defaults.name}${count.index}"
  policy           = local.bes_persistent_ssl[local.bes_persistent_ssl_keys[count.index]] != null ? (local.bes_persistent_ssl[local.bes_persistent_ssl_keys[count.index]].policy != null ? local.bes_persistent_ssl[local.bes_persistent_ssl_keys[count.index]].policy : local.backend_sets_defaults.policy) : local.backend_sets_defaults.policy

  health_checker {
    protocol            = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].protocol : local.health_check_defaults.protocol
    interval_ms         = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].interval_ms : local.health_check_defaults.interval_ms
    port                = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].port : local.health_check_defaults.port
    response_body_regex = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].response_body_regex : local.health_check_defaults.response_body_regex
    retries             = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].retries : local.health_check_defaults.retries
    return_code         = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].return_code : local.health_check_defaults.return_code
    timeout_in_millis   = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].timeout_in_millis : local.health_check_defaults.timeout_in_millis
    url_path            = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_persistent_ssl_keys[count.index]].health_check_name].url_path : local.health_check_defaults.url_path
  }

  session_persistence_configuration {
    cookie_name      = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].cookie_name != null ? var.backend_sets[local.bes_persistent_ssl_keys[count.index]].cookie_name : local.backend_sets_defaults.cookie_name
    disable_fallback = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].disable_fallback != null ? var.backend_sets[local.bes_persistent_ssl_keys[count.index]].disable_fallback : local.backend_sets_defaults.disable_fallback
  }

  ssl_configuration {
    certificate_name        = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].certificate_name != null ? var.backend_sets[local.bes_persistent_ssl_keys[count.index]].certificate_name : local.backend_sets_defaults.certificate_name
    verify_depth            = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].verify_depth != null ? var.backend_sets[local.bes_persistent_ssl_keys[count.index]].verify_depth : local.backend_sets_defaults.verify_depth
    verify_peer_certificate = var.backend_sets[local.bes_persistent_ssl_keys[count.index]].verify_peer_certificate != null ? var.backend_sets[local.bes_persistent_ssl_keys[count.index]].verify_peer_certificate : local.backend_sets_defaults.verify_peer_certificate
  }
}

# lb - no persistency, SSL
resource "oci_load_balancer_backend_set" "this_no_persistency_ssl" {
  count      = length(local.bes_ssl_keys)
  depends_on = [oci_load_balancer_certificate.this]

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.bes_ssl_keys[count.index] != null ? local.bes_ssl_keys[count.index] : "${local.backend_sets_defaults.name}${count.index}"
  policy           = local.bes_ssl[local.bes_ssl_keys[count.index]] != null ? (local.bes_ssl[local.bes_ssl_keys[count.index]].policy != null ? local.bes_ssl[local.bes_ssl_keys[count.index]].policy : local.backend_sets_defaults.policy) : local.backend_sets_defaults.policy

  health_checker {
    protocol            = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].protocol : local.health_check_defaults.protocol
    interval_ms         = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].interval_ms : local.health_check_defaults.interval_ms
    port                = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].port : local.health_check_defaults.port
    response_body_regex = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].response_body_regex : local.health_check_defaults.response_body_regex
    retries             = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].retries : local.health_check_defaults.retries
    return_code         = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].return_code : local.health_check_defaults.return_code
    timeout_in_millis   = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].timeout_in_millis : local.health_check_defaults.timeout_in_millis
    url_path            = var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name != null ? var.health_checks[var.backend_sets[local.bes_ssl_keys[count.index]].health_check_name].url_path : local.health_check_defaults.url_path
  }

  ssl_configuration {
    certificate_name        = var.backend_sets[local.bes_ssl_keys[count.index]].certificate_name != null ? var.backend_sets[local.bes_ssl_keys[count.index]].certificate_name : local.backend_sets_defaults.certificate_name
    verify_depth            = var.backend_sets[local.bes_ssl_keys[count.index]].verify_depth != null ? var.backend_sets[local.bes_ssl_keys[count.index]].verify_depth : local.backend_sets_defaults.verify_depth
    verify_peer_certificate = var.backend_sets[local.bes_ssl_keys[count.index]].verify_peer_certificate != null ? var.backend_sets[local.bes_ssl_keys[count.index]].verify_peer_certificate : local.backend_sets_defaults.verify_peer_certificate
  }
}

#################
# Backends
#################
# default values
locals {
  backends_defaults = {
    name       = "backend_"
    ip_address = null
    port       = 443
    backup     = false
    drain      = false
    offline    = false
    weight     = 1
  }


  /*
  LOGIC EXPLANATION - what's happening below:
# start with this:
> var.backend_sets
{
  "beset1" = {
    "backends" = {
      "web_1" = {
        "ip" = "192.168.1.1"
        "port" = 80
      }
      "web_2" = {
        "ip" = "192.168.1.2"
        "port" = 80
      }
    }
  }
  "beset2" = {
    "backends" = {
      "web_10" = {
        "ip" = "192.168.10.1"
        "port" = 80
      }
      "web_11" = {
        "ip" = "192.168.10.2"
        "port" = 80
      }
    }
  }
}
>
# this turns into:
> {for k,v in var.backend_sets : k => [ for k2,v2 in v["backends"] : { bes=k, name=k2, ip=v2["ip"], port=v2["port"] } ] }
{
  "beset1" = [
    {
      "bes" = "beset1"
      "ip" = "192.168.1.1"
      "name" = "web_1"
      "port" = 80
    },
    {
      "bes" = "beset1"
      "ip" = "192.168.1.2"
      "name" = "web_2"
      "port" = 80
    },
  ]
  "beset2" = [
    {
      "bes" = "beset2"
      "ip" = "192.168.10.1"
      "name" = "web_10"
      "port" = 80
    },
    {
      "bes" = "beset2"
      "ip" = "192.168.10.2"
      "name" = "web_11"
      "port" = 80
    },
  ]
}
>
  This allows us to reference local.be_servers[BACKEND_SET_NAME] in a for_each...
  In actuality, we don't need this to be a map, but rather a list suffices...
  
  Here's what we have:

> flatten( [ for k,v in var.backend_sets : [ for k2,v2 in v["backends"] : { bes=k, name=k2, ip=v2["ip"], port=v2["port"], backup=v2["backup"], drain=v2["drain"], offline=v2["offline"], weight=v2["weight"] } ] ] )
[
  {
    "backup" = false
    "bes" = "app1"
    "drain" = false
    "ip" = "192.168.10.2"
    "name" = "be1"
    "offline" = false
    "port" = 80
    "weight" = 1
  },
  {
    "backup" = false
    "bes" = "app1"
    "drain" = false
    "ip" = "192.168.10.3"
    "name" = "be2"
    "offline" = false
    "port" = 80
    "weight" = 1
  },
]
>

  Here's what happens without using flatten:
> [ for k,v in var.backend_sets : [ for k2,v2 in v["backends"] : { bes=k, name=k2, ip=v2["ip"], port=v2["port"], backup=v2["backup"], drain=v2["drain"], offline=v2["offline"], weight=v2["weight"] } ] ]
[
  [
    {
      "backup" = false
      "bes" = "app1"
      "drain" = false
      "ip" = "192.168.10.2"
      "name" = "be1"
      "offline" = false
      "port" = 80
      "weight" = 1
    },
    {
      "backup" = false
      "bes" = "app1"
      "drain" = false
      "ip" = "192.168.10.3"
      "name" = "be2"
      "offline" = false
      "port" = 80
      "weight" = 1
    },
  ],
]
>
  Notice the double, nested (blank/empty) lists... that's why flatten is used to "flatten" the list!

  Here's the formula in a more legible format:
  flatten( 
    [ for k,v in var.backend_sets : [ 
      for k2,v2 in v["backends"] : { 
        bes=k, 
        name=k2, 
        ip=v2["ip"], 
        port=v2["port"], 
        backup=v2["backup"], 
        drain=v2["drain"], 
        offline=v2["offline"], 
        weight=v2["weight"] 
        }
      ]
    ]
  )
  */
  /*
  be_servers_list = flatten([for k, v in var.backend_sets : [for k2, v2 in v.backends : { bes = k, name = k2, ip_address = v2.ip, port = v2.port, backup = v2.backup, drain = v2.drain, offline = v2.offline, weight = v2.weight }]])

  
  be_servers = { for v in local.be_servers_list : v.name => v }
}

# resource definition
resource "oci_load_balancer_backend" "this" {
  #count                 = length(local.be_servers)
  for_each   = local.be_servers
  depends_on = [oci_load_balancer_backend_set.this_no_persistency_no_ssl, oci_load_balancer_backend_set.this_no_persistency_ssl, oci_load_balancer_backend_set.this_persistency_no_ssl, oci_load_balancer_backend_set.this_persistency_ssl]

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  backendset_name  = each.key
  ip_address       = each.value.ip_address != null ? each.value.ip_address : local.backends_defaults.ip_address
  port             = each.value.port != null ? each.value.port : local.backends_defaults.port

  backup  = each.value.backup != null ? each.value.backup : local.backends_defaults.backup
  drain   = each.value.drain != null ? each.value.drain : local.backends_defaults.drain
  offline = each.value.offline != null ? each.value.offline : local.backends_defaults.offline
  weight  = each.value.weight != null ? each.value.weight : local.backends_defaults.weight
}
*/

  be_servers            = flatten( [ for k,v in var.backend_sets : [ for k2,v2 in v.backends : { bes=k, name=k2, ip_address=v2.ip, port=v2.port, backup=v2.backup, drain=v2.drain, offline=v2.offline, weight=v2.weight } ] ] )
}

# resource definition
resource "oci_load_balancer_backend" "this" {
  count                 = length(local.be_servers)
  depends_on            = [ oci_load_balancer_backend_set.this_no_persistency_no_ssl, oci_load_balancer_backend_set.this_no_persistency_ssl, oci_load_balancer_backend_set.this_persistency_no_ssl, oci_load_balancer_backend_set.this_persistency_ssl ]

  load_balancer_id      = oci_load_balancer_load_balancer.this[0].id
  backendset_name       = local.be_servers[count.index].bes != null ? local.be_servers[count.index].bes : "${local.backends_defaults.name}${count.index}"
  ip_address            = local.be_servers[count.index].ip_address != null ? local.be_servers[count.index].ip_address : local.backends_defaults.ip_address
  port                  = local.be_servers[count.index].port != null ? local.be_servers[count.index].port : local.backends_defaults.port

  backup                = local.be_servers[count.index].backup != null ? local.be_servers[count.index].backup : local.backends_defaults.backup
  drain                 = local.be_servers[count.index].drain != null ? local.be_servers[count.index].drain : local.backends_defaults.drain
  offline               = local.be_servers[count.index].offline != null ? local.be_servers[count.index].offline : local.backends_defaults.offline
  weight                = local.be_servers[count.index].weight != null ? local.be_servers[count.index].weight : local.backends_defaults.weight
}


#################
# Path Route Sets
#################
# default values
locals {
  path_rt_set_options_defaults = {
    name   = "path_rt_set_"
    routes = []
  }
  path_rt_sets      = { for k, v in(var.path_route_sets != null ? var.path_route_sets : {}) : k => v }
  path_rt_sets_keys = keys(local.path_rt_sets)
}

# resource definition
resource "oci_load_balancer_path_route_set" "this" {
  count      = length(local.path_rt_sets_keys)
  depends_on = [oci_load_balancer_backend_set.this_no_persistency_no_ssl, oci_load_balancer_backend_set.this_no_persistency_ssl, oci_load_balancer_backend_set.this_persistency_no_ssl, oci_load_balancer_backend_set.this_persistency_ssl]

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.path_rt_sets_keys[count.index] != null ? local.path_rt_sets_keys[count.index] : "${local.path_rt_set_options_defaults.name}${count.index}"

  # iterate through all of the defined path_routes items, if they exist, and populate blocks for each one...
  dynamic "path_routes" {
    iterator = item
    for_each = local.path_rt_sets[local.path_rt_sets_keys[count.index]]

    content {
      backend_set_name = item.value.backend_set_name
      path             = item.value.path
      path_match_type {
        match_type = item.value.match_type
      }
    }
  }
}

#################
# Rule Set
#################
# default values
locals {
  rule_set_options_defaults = {
    name  = "rule_set_"
    rules = []
  }
  # rule_sets          = flatten( [ for k,v in var.listeners : [ for k2,v2 in (v.rule_sets != null ? v.rule_sets : {} ) : { name=k2, items=v2 } ] ] )
  rule_sets      = { for k, v in(var.rule_sets != null ? var.rule_sets : {}) : k => v }
  rule_sets_keys = keys(local.rule_sets)
}

# resource definition
resource "oci_load_balancer_rule_set" "this" {
  count = length(local.rule_sets_keys)

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.rule_sets_keys[count.index] != null ? local.rule_sets_keys[count.index] : "${local.rule_set_options_defaults.name}${count.index}"

  # iterate through all of the defined rule_set items (rules), if they exist, and populate blocks for each one...
  dynamic "items" {
    iterator = rule
    for_each = local.rule_sets[local.rule_sets_keys[count.index]]

    content {
      action = rule.value.action
      header = rule.value.header
      prefix = rule.value.prefix
      suffix = rule.value.suffix
      value  = rule.value.value
    }
  }
}

#################
# Listeners
#################
# default values
locals {
  listeners_defaults = {
    name                    = "listener_"
    port                    = 80
    protocol                = "HTTP"
    idle_timeout            = 60
    hostnames               = []
    path_route_set_name     = null
    rule_set_names          = null
    enable_ssl              = false
    certificate_name        = null
    verify_depth            = 3
    verify_peer_certificate = true
  }

  listeners_no_ssl = { for k, v in var.listeners :
    k => {
      name                     = k
      default_backend_set_name = v.default_backend_set_name
      port                     = v.port
      protocol                 = v.protocol
      idle_timeout             = v.idle_timeout
      hostnames                = [for i in(v.hostnames != null ? v.hostnames : local.listeners_defaults.hostnames) : "${k}_${i}"]
      path_route_set_name      = v.path_route_set_name
      rule_set_names           = v.rule_set_names
    } if v.enable_ssl != true
  }
  listeners_no_ssl_keys = keys(local.listeners_no_ssl)

  listeners_ssl = { for k, v in var.listeners :
    k => {
      name                     = k
      default_backend_set_name = v.default_backend_set_name
      port                     = v.port
      protocol                 = v.protocol
      idle_timeout             = v.idle_timeout
      hostnames                = [for i in(v.hostnames != null ? v.hostnames : local.listeners_defaults.hostnames) : "${k}_${i}"]
      path_route_set_name      = v.path_route_set_name
      rule_set_names           = v.rule_set_names
      enable_ssl               = v.enable_ssl
      certificate_name         = v.certificate_name
      verify_depth             = v.verify_depth
      verify_peer_certificate  = v.verify_peer_certificate
    } if v.enable_ssl == true
  }
  listeners_ssl_keys = keys(local.listeners_ssl)
}

# resource definition
resource "oci_load_balancer_listener" "this_no_ssl" {
  count      = length(local.listeners_no_ssl_keys)
  depends_on = [oci_load_balancer_backend_set.this_no_persistency_no_ssl, oci_load_balancer_backend_set.this_no_persistency_ssl, oci_load_balancer_backend_set.this_persistency_no_ssl, oci_load_balancer_backend_set.this_persistency_ssl, oci_load_balancer_path_route_set.this, oci_load_balancer_rule_set.this, oci_load_balancer_hostname.this]

  # we cannot assume a default for this, so requiring a value for it (no default used)
  default_backend_set_name = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].default_backend_set_name
  load_balancer_id         = oci_load_balancer_load_balancer.this[0].id
  name                     = local.listeners_no_ssl_keys[count.index] != null ? local.listeners_no_ssl_keys[count.index] : "${local.listeners_defaults.name}${count.index}"
  port                     = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].port != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].port : local.listeners_defaults.port
  protocol                 = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].protocol != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].protocol : local.listeners_defaults.protocol

  connection_configuration {
    idle_timeout_in_seconds = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].idle_timeout != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].idle_timeout : local.listeners_defaults.idle_timeout
  }
  hostname_names      = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].hostnames != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].hostnames : local.listeners_defaults.hostnames
  path_route_set_name = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].path_route_set_name != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].path_route_set_name : local.listeners_defaults.path_route_set_name
  rule_set_names      = local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].rule_set_names != null ? local.listeners_no_ssl[local.listeners_no_ssl_keys[count.index]].rule_set_names : local.listeners_defaults.rule_set_names
}

resource "oci_load_balancer_listener" "this_ssl" {
  count      = length(local.listeners_ssl_keys)
  depends_on = [oci_load_balancer_backend_set.this_no_persistency_no_ssl, oci_load_balancer_backend_set.this_no_persistency_ssl, oci_load_balancer_backend_set.this_persistency_no_ssl, oci_load_balancer_backend_set.this_persistency_ssl, oci_load_balancer_path_route_set.this, oci_load_balancer_rule_set.this, oci_load_balancer_hostname.this, oci_load_balancer_certificate.this]

  # we cannot assume a default for this, so requiring a value for it (no default used)
  default_backend_set_name = local.listeners_ssl[local.listeners_ssl_keys[count.index]].default_backend_set_name
  load_balancer_id         = oci_load_balancer_load_balancer.this[0].id
  name                     = local.listeners_ssl_keys[count.index] != null ? local.listeners_ssl_keys[count.index] : "${local.listeners_defaults.name}${count.index}"
  port                     = local.listeners_ssl[local.listeners_ssl_keys[count.index]].port != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].port : local.listeners_defaults.port
  protocol                 = local.listeners_ssl[local.listeners_ssl_keys[count.index]].protocol != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].protocol : local.listeners_defaults.protocol

  connection_configuration {
    idle_timeout_in_seconds = local.listeners_ssl[local.listeners_ssl_keys[count.index]].idle_timeout != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].idle_timeout : local.listeners_defaults.idle_timeout
  }
  hostname_names      = local.listeners_ssl[local.listeners_ssl_keys[count.index]].hostnames != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].hostnames : local.listeners_defaults.hostnames
  path_route_set_name = local.listeners_ssl[local.listeners_ssl_keys[count.index]].path_route_set_name != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].path_route_set_name : local.listeners_defaults.path_route_set_name
  rule_set_names      = local.listeners_ssl[local.listeners_ssl_keys[count.index]].rule_set_names != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].rule_set_names : local.listeners_defaults.rule_set_names
  ssl_configuration {
    certificate_name        = local.listeners_ssl[local.listeners_ssl_keys[count.index]].certificate_name != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].certificate_name : local.listeners_defaults.certificate_name
    verify_depth            = local.listeners_ssl[local.listeners_ssl_keys[count.index]].verify_depth != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].verify_depth : local.listeners_defaults.verify_depth
    verify_peer_certificate = local.listeners_ssl[local.listeners_ssl_keys[count.index]].verify_peer_certificate != null ? local.listeners_ssl[local.listeners_ssl_keys[count.index]].verify_peer_certificate : local.listeners_defaults.verify_peer_certificate
  }
}

#################
# Hostnames
#################
# default values
locals {
  hostnames_defaults = {
    name     = "hostname_"
    hostname = null
  }
  hostnames = flatten([for k, v in var.listeners : (v.hostnames != null ? [for v2 in v.hostnames : { listener_name = k, hostname = v2, name = "${k}_${v2}" }] : [])])
}

# resource definition
resource "oci_load_balancer_hostname" "this" {
  count = length(local.hostnames)

  load_balancer_id = oci_load_balancer_load_balancer.this[0].id
  name             = local.hostnames[count.index].name != null ? local.hostnames[count.index].name : "${local.hostnames_defaults.name}${count.index}"
  hostname         = local.hostnames[count.index].hostname != null ? local.hostnames[count.index].hostname : local.hostnames_defaults.hostname
}
