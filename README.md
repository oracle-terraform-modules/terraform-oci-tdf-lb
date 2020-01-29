# Oracle Cloud Infrastructure Load Balancer Module for Terraform

## Introduction

This module serves as a foundational component in an OCI environment, providing the ability to provision a load balancer (LB) in OCI.

## Solution

LBs are a common primary mechanism for accessing many web-based applications, whether over private IP addresses or public IP addresses. This module provides the ability to create the following resources:

| Resource | Created by Default? |
|---|---|
| LB | Yes |
| Listeners | No |
| Hostnames | No |
| Certificates | No |
| Backend Sets | No |
| Backends | No |
| Path Route Sets | No |
| Rule Sets | No |

By using this module, at minimum, a load balancer (LB) will be created. The additional resources mentioned above may be created (up to the user).

### Prerequisites

Create the following before using this module: 
  * Required IAM construct to allow for the creation of resources
  * VCNs/Subnets

The following are not required to create the FSS resources, but are required for traffic to flow:
  * Security List(s)
    * The *network_security* module may be used to create and manage NFS Security Lists.
  * Route Table
    * Often times only a couple of routing policies exist and are created in the *network* module.
  * DHCP Options
    * Often times only a couple of DHCP Options (DNS profiles) exist and are created in the *network* module.

## Getting Started

Several fully-functional examples have been provided in the `examples` directory.  Please reference the `README.md` in each example directory for any directions specific to the example.

For getting going quickly, at minimum, you need the following (for the most basic deployment):

```
module "oci_lb" {
  source                  = "git::ssh://git@orahub.oraclecorp.com/dev-sdf-ateam/terraform-oci-tdf-lb.git"
  
  default_compartment_id  = var.default_compartment_id
  
  lb_options            = {
    display_name        = "test_lb"
    compartment_id      = null
    shape               = "100Mbps"
    subnet_ids          = [oci_core_subnet.this.id]
    private             = true
    nsg_ids             = null
    defined_tags        = null
    freeform_tags       = null
  }
}
```

This will deploy a LB using the module defaults (review this document for a detailed description of these).


## Accessing the Solution

This is a core service module and no access is provided to the Load Balancer Service. 

You may continue to manage the environment using Terraform (ideal), OCI CLI, OCI console (UI), directly via the API, etc.


## Module inputs

### LB

| Attribute | Data Type | Required | Default Value | Valid Values | Description |
|---|---|---|---|---|---|
| default\_compartment\_id | string | yes | none | string of the compartment OCID | This is the default OCID that will be used when creating objects (unless overridden for any specific object). This needs to be the OCID of a pre-existing compartment (it will not create the compartment). |
| lb\_options | map | no | see below | see below | The optional parameters that can be used to customize the LB. |

**`lb_options`**

The `lb_options` attribute is an optional map attribute. Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values). It has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| display\_name | string | "lb" | Any name acceptable to the OCI API. | Used to define a specific name for your LB. |
| compartment\_id | string | null | Compartment OCID | Pre-existing compartment OCID (if default compartment is not to be used).  If this value is null, the default compartment OCID will be used. |
| shape | string | The first element in the `data.oci_load_balancer_shapes.this.shapes` data source (list). | Shape name | Specify the name of the LB instance shape. |
| subnet\_ids | list of strings | null | List of subnet ID(s)| The subnet ID(s) that the LB should be placed in. |
| private | bool | true | true (private) or false (public) | Whether or not the LB should be a private LB (true) or a public LB (false). |
| nsg\_ids | list of strings | [] | IDs of the NSG(s) that the LB should be a part of. | The list of OCIDs (IDs) for the NSGs that the LB should be a part of. |
| defined\_tags | map(string) | {} | Any map of tag names and values that is acceptable to the OCI API. | If any Defined Tags should be set on this resource, do so with this attribute. |
| freeform\_tags | map(string) | {} | Any map of tag names and values that is acceptable to the OCI API. | If any Freeform Tags should be set on this resource, do so with this attribute. |

***Example***

The following example will create a private LB with a display name of *test_lb*, shape of 100 Mbps in a single subnet, using the default compartment OCID.

```
module "oci_lb" {
  ... /snip - shortened for brevity...

  default_compartment_id  = var.default_compartment_id
  
  lb_options = {
    display_name    = "test_lb"
    compartment_id  = null
    shape           = "100Mbps"
    subnet_ids      = [oci_core_subnet.this.id]
    private         = true
    nsg_ids         = null
    defined_tags    = null
    freeform_tags   = null
  }
}
```


### Certificates

Certificates can be used by Listeners as well as Backend Sets. They are defined using the `certificates` variable, then referenced (as-needed) in the `listeners` and/or `backend_sets` definitions.

**`certificates`**

The `certificates` variable is an optional map attribute.  The key for each map is the name of the certificate.  Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values).  It has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| ca\_certificate | string | null | The value of a CA certificate. | Provide the certificate used by the CA for the certificate being defined. |
| passphrase | string | null | null or the string of the passphrase | If a passphrase is used with the private key, please provide that as a string value, otherwise use null. |
| private\_key | string | null | The value of a valid OCI private key (PEM format) | Provide the contents of your private key here. |
| public\_certificate | string | null | The value of a valid OCI public certificate (PEM format) | Provide the contents of your public certificate here. |

Example:

```
module "oci_lb" {
  ... /snip - shortened for brevity...

  certificates            = {
    test123               = {
      ca_certificate      = file("./certs/ca.crt")
      passphrase          = null
      private_key         = file("./certs/my_cert.key")
      public_certificate  = file("./certs/my_cert.crt")
    }
  }
}
```

The above example will create a Certificate with a name of `test123`, referencing the contents of pre-existing files (`./certs/ca.crt`, `./certs/my_cert.key` and `./certs/my_cert.crt`), without the use of a passphrase.

### Listeners

Listeners are composed of several potential components:

* Listener parameters (`listeners`)
* Certificate (`certificates`)
* Path Route Set (`path_route_sets`)
* Rule Set(s) (`rule_sets`)

Each of these are described below (with the exception of `certificates`, which is described above).

**`listeners`**

The `listeners` attribute is an optional map attribute. This is how listeners are setup on the LB. Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values).

The name of the listener is the map key, with its attributes being the values of the entry.  It has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| default\_backend\_set\_name | string | No default value (must be provided) | The name of a Backend Set that can be used. | Used to define a default Backend Set for use with the listener. |
| port | number | 80 | A valid HTTP/TCP port number. | This is where you tell the listener the port it'll be listening on. |
| protocol | string | "HTTP" | "HTTP", "TCP" (or any other valid, acceptable values - see [ListProtocols](https://docs.cloud.oracle.com/iaas/api/#/en/loadbalancer/20170115/LoadBalancerProtocol/ListProtocols) for the official list). | The specific protocol that the listener should operate on. |
| idle_timeout | number | 60 | Number of seconds. | How many seconds should a session wait idle? |
| hostnames | list of strings | [] | The DNS hostnames that should be associated with this listener. | Give one or more valid DNS hostnames that should be associated with this listener. |
| path\_route\_set\_name | string | null | The name of a Path Route Set. | This is an optional parameter, where the name of a Path Route Set can be associated with the listener. |
| rule\_set\_names | list of strings | null | Rule Set name(s). | This is optional, allowing you to specify zero, one or more Rule Set names to associate with this listener. |
| enable\_ssl | bool | false | true or false | Whether or not the listener should have SSL enabled. |
| certificate\_name | string | null | The name of a Certificate to use for the SSL. | If SSL is enabled, specify the Certificate name here. |
| verify\_depth | number | 3 | A valid numeric value. | Specify how far to verify the peer chain. |
| verify\_peer\_certificate | bool | true | true or false | Whether or not to validate the peer certificate. |

***Example***

The following example will create a single listener (`app1`) using a default Backend Set of the same name (`app1`), using HTTP on port 80, with an idle timeout of 180, responding to requests to the `app1.myorg.local` and `app1-test.myorg.local` hostnames, routing requests using the `app1_routes` Path Route Set and making modifications as dictated by the `add_header` Rule Set. SSL is not enabled.


```
module "oci_lb" {
  ... /snip - shortened for brevity...

  listeners               = {
    app1                  = {
      default_backend_set_name = "app1"
      port                = 80
      protocol            = "HTTP"
      idle_timeout        = 180
      hostnames           = [ "app1.myorg.local", "app1-test.myorg.local" ]
      path_route_set_name = "app1_routes"
      rule_set_names      = [ "add_header" ]
      enable_ssl          = false
      certificate_name    = "app1"
      verify_depth        = 5
      verify_peer_certificate = true
    }
  }
}
```


**path\_route\_sets**

The `path_route_sets` attribute is an optional map attribute. The key for each map is the name of the Path Route Set. The value is a list of maps, which comprise the list of rules in the Path Route Set. Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values). Each map in the list (rule) has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| backend\_set\_name | string | No default value (must be provided by the user) | The name of a Backend Set. | Specify the Backend Set to be used for traffic matching this path route rule. |
| path | string | No default value (must be provided by the user) | A valid HTTP path | Provide the HTTP path (as a string) that should be used for the specific rule. |
| match\_type | string | No default value (must be provided by the user) | `"EXACT_MATCH"`, `"FORCE_LONGEST_PREFIX_MATCH"`, `"PREFIX_MATCH"`, `"SUFFIX_MATCH"` | The type of match to be used for this rule. |

***Example***

The following example will create two Path Route Sets (`app1_routes` and `test_app_routes`), with each having three rules. Each of the three rules reference a unique HTTP path and all use the same common `PREFIX_MATCH` match_type and the same Backend Set name (`app1`).

```
module "oci_lb" {
  ... /snip - shortened for brevity...

  path_route_sets         = {
    app1_routes           = [
      {
        backend_set_name = "app1"
        path            = "/"
        match_type      = "PREFIX_MATCH"
      },
      {
        backend_set_name = "app1"
        path            = "/login"
        match_type      = "PREFIX_MATCH"
      },
      {
        backend_set_name = "app1"
        path            = "/login_new"
        match_type      = "PREFIX_MATCH"
      }
    ],
    test_app_routes       = [
      {
        backend_set_name = "app1"
        path            = "/"
        match_type      = "PREFIX_MATCH"
      },
      {
        backend_set_name = "app1"
        path            = "/login"
        match_type      = "PREFIX_MATCH"
      },
      {
        backend_set_name = "app1"
        path            = "/login_new"
        match_type      = "PREFIX_MATCH"
      }
    ]
  }
}
```



**rule\_sets**

The `rule_sets` attribute is an optional map attribute. The key for each map is the name of the Rule Set. The value is a list of maps, which provide the different items that the Rule Set will do. Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values). Each map in the list (item) has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| action | string | No default value (must be provided by the user) | `"ADD_HTTP_REQUEST_HEADER"`, `"ADD_HTTP_RESPONSE_HEADER"`, `"EXTEND_HTTP_REQUEST_HEADER_VALUE"`, `"EXTEND_HTTP_RESPONSE_HEADER_VALUE"`, `"REMOVE_HTTP_REQUEST_HEADER"`, `"REMOVE_HTTP_RESPONSE_HEADER"` | Specify the action to be performed by the Rule Set item. |
| header | string | No default value (must be provided by the user) | The HTTP header to manipulate | Specify the HTTP header that should be manipulated, added or removed. |
| prefix | string | No default value (must be provided by the user) | A valid prefix | This is an optional attribute, if a prefix is desired. |
| suffix | string | No default value (must be provided by the user) | A valid suffix | This is an optional attribute, if a suffix is desired. |
| value | string | No default value (must be provided by the user) | A valid value | (Required when action=ADD_HTTP_REQUEST_HEADER | ADD_HTTP_RESPONSE_HEADER)  A header value that conforms to RFC 7230 |


***Example***
The following example will create two Rule Sets (`fix_headers` and `add_header`). Each of the Rule Sets has one or more items that are designed to manipulated the HTTP response or request headers.

```
module "oci_lb" {
  ... /snip - shortened for brevity...

  rule_sets           = {
    fix_headers       = [
      {
        action        = "ADD_HTTP_REQUEST_HEADER"
        header        = "TEST1"
        prefix        = null
        suffix        = null
        value         = "hello world"
      },
      {
        action        = "REMOVE_HTTP_RESPONSE_HEADER"
        header        = "X-Forwarded-For"
        prefix        = null
        suffix        = null
        value         = null
      }
    ],
    add_header        = [
      {
        action        = "ADD_HTTP_RESPONSE_HEADER"
        header        = "Served_by"
        prefix        = null
        suffix        = null
        value         = "the best server in the world"
      }
    ]
  }
}
```



### Backend Sets

Backend Sets are composed of several potential components:

* Backend Set parameters (`backend_sets`)
* Backends (defined in `backend_sets`)
* Certificates (`certificates` - previously described in this document)
* Health Check (`health_checks`)

Each of these are described below (with the exception of `certificates`, which is described above).

**health\_checks**

The `health_checks` attribute is a required map attribute when one or more Backend Sets are defined (largely because it's required by `backend_sets`).  The key is a name given to the `health_check`, which is then referenced in the `backend_set`.  Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values).  Each entry in the map has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| protocol | string | `data.oci_load_balancer_protocols.this.protocols[0].name` | Any protocol acceptable to the OCI API. | Provide the specific protocol to be used for the health check. |
| interval\_ms | number | 1000 | A valid numeric value | Specify the number of ms between when the health check should be re-run. |
| port | number | 443 | A valid port number | Specify the TCP port to be used for the health check. |
| response\_body\_regex | string | `".*"` | Any valid regular expression (RegEx) | You can specify a RegEx that the health check should use. |
| retries | number | 3 | Any valid number of retries | Tell it how many retries to attempt. |
| return\_code | number | 200 | A valid HTTP response code | Specify the HTTP return code to be expected upon a successful call to the path. |
| timeout\_in\_millis | number | 3000 | Any value acceptable to the OCI API. | How long should it wait until timing out? |
| url\_path | string | `"/"` | A valid HTTP path | Specify the path to be used in the health check test. |

***Example***
The following example defines a health check which can be referenced in a `backend_sets` entry, using HTTP, port 80, looking for a 200 HTTP response code (querying the root path and accepting any returned value with the very broad RegEx used).

```
module "oci_lb" {
  ... /snip - shortened for brevity...

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
}
```


**backend\_sets**

The `backend_sets` attribute is an optional map attribute which can be used to define different Backend Sets for the LB. The key of the map provides the name of the Backend Set, with different attributes provided in the value of the map. Note that if this attribute is used, all keys/values must be specified (Terraform does not allow for default or optional map keys/values).  Each entry has the following defined keys (and default values):

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| policy | string | `data.oci_load_balancer_policies.this.policies[0].name` | Any value acceptable to the OCI API. | This is where you tell the LB what kind of policy to apply for the Backend Set. |
| health\_check\_name | string | null | The name of a `health_check` entry to use for the Backend Set | Here's where you specify the name of the health check that has been defined. |
| enable\_persistency | bool | true | true or false | Whether or not persistency should be enabled for the Backend Set. |
| cookie\_name | string | `"'*'"` | The name of the cookie to use for persistency | Specify the string name of the cookie to use for tracking session persistency on the HTTP flow. |
| disable\_fallback | bool | false | true or false | If the backend for the persistent session is unavailable, should it be redirected to another available backend? |
| enable\_ssl | bool | false | true or false | Whether or not SSL should be enabled for the Backend Set. |
| certificate\_name | string | null | The name of the Certificate to be used for the Backend Set | If SSL is enabled, specify the Certificate to be used for the Backend Set here. |
| verify\_depth | number | 3 | A number valid in the OCI API | This is where you specify how far should verification go. |
| verify\_peer\_certificate | bool | true | true or false | Whether or not the peer certificate should be verified. |
| backends | map | {} | See below for a description | This is where each Backend is defined for the Backend Set. |

The `backends` attribute mentioned above is a map, where the key defines the name of the Backend and each entry has the following attributes:

| Key | Data Type | Default Value | Valid Values | Description |
|---|---|---|---|---|
| ip | string | null | A valid IP address | Provide the valid IP address of the Backend. |
| port | number | 443 | A valid TCP port | Provide the valid TCP port to be used for the Backend. |
| backup | bool | false | true or false | Whether or not the Backend should be considered as a backup. |
| drain | bool | false | true or false | Whether or not the Backend should not receive new connections (drain the existing connections). |
| offline | bool | false | true or false | Whether or not the Backend should be considered offline. |
| weight | number | 1 | A valid number acceptable by the OCI API | The weight for the Backend (used to influence how much traffic is directed to the Backend). |

***Example***

The following example will create a Backend Set as well as two Backends. Persistency and SSL is not enabled for the Backend Set.

```
module "oci_lb" {
  ... /snip - shortened for brevity...

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
}
```



## Outputs

Each discrete resource that's created by the module will be exported, allowing for access to all returned attributes for the resource.  Here are the different outputs:

| Resource | Always returned? | Description |
|---|---|---|
| lb | yes | The LB resource that has been created by the module. |
| lb_protocols | yes | The different available protocols. |
| lb_shapes | yes | The different available shapes. |
| certificates | no* | The Certificate resource(s) created by the module (if it was requested/created). |
| backend\_sets | no* | The different Backend Sets that have been created by the module.  Also contains the different Backends belonging to each Backend Sets (contained in the `backends` attribute. |
| backends | no* | The Backend resources created by the module (if it was requested/created). |
| path\_route\_sets | no* | The Path Route Set resources created by the module (if it was requested/created). |
| rule\_sets | no* | The Rule Set resources created by the module (if it was requested/created). |
| hostnames | no* | The Hostname resources created by the module (if it was requested/created). |
| listeners | no* | The Listener resources created by the module (if it was requested/created).  Note that the different hostnames are also given in the `hostnames` attribute (in addition to the standard Listener attributes). |

*only returned when the resource has been requested to be created.

Note that you may still reference the outputs (even if they're not returned) without causing an error in Terraform (it must be smart enough to know not to throw an error in these cases).


## Notes/Issues

* Note that if you provide any single element in the different resource maps (`lb_options`, `listeners`, `backend_sets`, etc), you must provide all of them.  Maps do not have a notion of an optional (or default value) for keys within the map, requiring that all keys/values be passed (if one key is passed, all keys must be passed).

## Release Notes

See [release notes](./docs/release_notes.md) for release notes information.

## URLs

* [https://www.terraform.io/docs/providers/oci/r/load_balancer_listener.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_listener.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_hostname.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_hostname.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_rule_set.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_rule_set.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_path_route_set.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_path_route_set.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_certificate.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_certificate.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_backend_set.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_backend_set.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_backend.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_backend.html)
* [https://www.terraform.io/docs/providers/oci/r/load_balancer_load_balancer.html](https://www.terraform.io/docs/providers/oci/r/load_balancer_load_balancer.html)

## Contributing

This project is open source. Oracle appreciates any contributions that are made by the open source community.

## License

Copyright (c) 2020 Oracle and/or its affiliates. 

Licensed under the Universal Permissive License 1.0 

See [LICENSE](LICENSE) for more details.
