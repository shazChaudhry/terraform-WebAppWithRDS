variable "region" {
  description = "AWS London region to launch servers"
  default     = "eu-west-2"
}

variable "credentials" {
  default = "~/.aws/credentials"
}

variable "DnsZoneName" {
  default     = "ci.internal"
  description = "the internal dns name"
}

variable "tags" {
  default     = ["DevOps", "CI"]
  description = "Project tags"
}
