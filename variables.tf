
# Global variables

variable "default_compartment_id" {
  type              = string
  description       = "The default compartment OCID to use for resources (unless otherwise specified)."
}

# LB-specific variables
variable "lb_options" {
  type              = object({
    display_name    = string,
    compartment_id  = string,
    shape           = string,
    subnet_ids      = list(string),
    private         = bool,
    nsg_ids         = list(string),
    defined_tags    = map(string),
    freeform_tags   = map(string)
  })
  description       = "Parameters for customizing the LB."
  default           = {
    display_name    = null
    compartment_id  = null
    shape           = null
    subnet_ids      = null
    private         = null
    nsg_ids         = null
    defined_tags    = null
    freeform_tags   = null
  }
}

# Certificates-specific variables
variable "certificates" {
  type                  = map(object({
    ca_certificate      = string,
    passphrase          = string,
    private_key         = string,
    public_certificate  = string,
  }))
  description           = "Parameters for Certificates."
  default               = {}
}

# Backend-sets-specific variables
variable "backend_sets" {
  type                  = map(object({
    policy              = string,
    health_check_name   = string,
    enable_persistency  = bool,
    cookie_name         = string,
    disable_fallback    = bool,
    enable_ssl          = bool,
    certificate_name    = string,
    verify_depth        = number,
    verify_peer_certificate = bool,
    backends            = map(object({
      ip                = string,
      port              = number,
      backup            = bool,
      drain             = bool,
      offline           = bool,
      weight            = number
    }))
  }))
  description           = "Parameters for Backend Sets."
  default               = {}
}

# Health Check variables
variable "health_checks" {
  type                  = map(object({
    protocol            = string,
    interval_ms         = number,
    port                = number,
    response_body_regex = string,
    retries             = number,
    return_code         = number,
    timeout_in_millis   = number,
    url_path            = string
  }))
  description           = "Parameters for health checks (used by Backend Sets)."
  default               = {}
}

# Path Route Set-specific variables
variable "path_route_sets" {
  type                  = map(list(object({
    backend_set_name    = string,
    path                = string,
    # valid values: EXACT_MATCH, FORCE_LONGEST_PREFIX_MATCH, PREFIX_MATCH, SUFFIX_MATCH
    match_type          = string
  })))
  description           = "Parameters for Path Route Sets."
  default               = {}
}

# Rule Set-specific variables
variable "rule_sets" {
  type                  = map(list(object({
    action              = string,
    header              = string,
    prefix              = string,
    suffix              = string,
    value               = string
  })))
  description           = "Parameters for Rule Sets."
  default               = {}
}

# Listener-specific variables
variable "listeners" {
  type                  = map(object({
    default_backend_set_name = string,
    port                = number,
    protocol            = string,
    idle_timeout        = number,
    hostnames           = list(string),
    path_route_set_name = string,
    rule_set_names      = list(string),
    enable_ssl          = bool,
    certificate_name    = string,
    verify_depth        = number,
    verify_peer_certificate = bool
  }))
  description           = "Parameters for Listeners."
  default               = {}
}
