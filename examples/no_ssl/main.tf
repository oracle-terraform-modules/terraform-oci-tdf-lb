# Copyright (c) 2020 Oracle and/or its affiliates.
# Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.

module "oci_lb" {
  source                  = "../../"
  
  default_compartment_id  = var.default_compartment_id
  
  lb_options              = {
    display_name          = "test_lb"
    compartment_id        = null
    shape                 = "100Mbps"
    subnet_ids            = [oci_core_subnet.this.id]
    private               = true
    nsg_ids               = null
    defined_tags          = null
    freeform_tags         = null
  }

  health_checks           = {
    basic_http            = {
      protocol            = "HTTP"
      interval_ms         = 1000
      port                = 80
      response_body_regex = ".*"
      retries             = 3
      return_code         = 200
      timeout_in_millis   = 3000
      url_path            = "/"
    }
  }

  backend_sets            = {
    app1                  = {
      policy              = "ROUND_ROBIN"
      health_check_name   = "basic_http"
      enable_persistency  = false
      enable_ssl          = false
      
      cookie_name         = null
      disable_fallback    = null
      certificate_name    = null
      verify_depth        = null
      verify_peer_certificate = null

      backends            = {
        be1               = {
          ip              = "192.168.10.2"
          port            = 80
          backup          = false
          drain           = false
          offline         = false
          weight          = 1
        },
        be2               = {
          ip              = "192.168.10.3"
          port            = 80
          backup          = false
          drain           = false
          offline         = false
          weight          = 1
        }
      }
    }
  }

  listeners               = {
    app1                  = {
      default_backend_set_name = "app1"
      port                = 80
      protocol            = "HTTP"
      idle_timeout        = 180
      hostnames           = [ "myapp.myorg.local" ]
      path_route_set_name = null
      rule_set_names      = null
      enable_ssl          = false
      certificate_name    = null
      verify_depth        = 5
      verify_peer_certificate = true
    }
  }
}

resource "oci_core_vcn" "this" {
  dns_label               = "temp"
  cidr_block              = "192.168.0.0/16"
  compartment_id          = var.default_compartment_id
  display_name            = "temp"
}

resource "oci_core_subnet" "this" {
  cidr_block              = "192.168.0.0/24"
  compartment_id          = var.default_compartment_id
  vcn_id                  = oci_core_vcn.this.id

  display_name            = "test"
  dns_label               = "test"
  prohibit_public_ip_on_vnic = false
}
