variable "region" {
  description = "AWS region"
  default     = "ap-northeast-2"
}

variable "prefix" {
  description = "Prefix for all resources"
  default     = "terra"
}

variable "app_1_domain" {
  description = "backend domain"
  default     = "api.stamppop.shop"
}
