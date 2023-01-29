variable "default_tags_enabled" {
  description = "Option to enable or disable default tags"
  type        = bool
  default     = true
}

variable "extra_tags" {
  description = "Additional tags to associate with resources"
  type        = map(string)
  default     = {}
}

variable "ani_extra_tags" {
  description = "Additional tags to associate with your network interface."
  type        = map(string)
  default     = {}
}

variable "pubip_extra_tags" {
  description = "Additional tags to associate with your public ip."
  type        = map(string)
  default     = {}
}

variable "storage_os_disk_tagging_enabled" {
  description = "Should OS disk tagging be enabled? Defaults to `true`."
  type        = bool
  default     = true
}

variable "storage_os_disk_extra_tags" {
  description = "Additional tags to set on the OS disk."
  type        = map(string)
  default     = {}
}

variable "extensions_extra_tags" {
  description = "Extra tags to set on the VM extensions."
  type        = map(string)
  default     = {}
}

variable "storage_os_disk_overwrite_tags" {
  description = "True to overwrite existing OS disk tags instead of merging."
  type        = bool
  default     = false
}