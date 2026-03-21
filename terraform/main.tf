data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "resume" {
  bucket           = format("resume-%s-%s-an", data.aws_caller_identity.current.account_id, data.aws_region.current.region)
  bucket_namespace = "account-regional"
  force_destroy    = true
}

data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.resume.arn}/*"
    ]

    condition {
      test     = "StringLike"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.resume_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.resume.id
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

locals {
  s3_origin_id = "resumebucket"
  my_domain    = "gregoryeberwine.com"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "mydomain" {
  domain_name               = local.my_domain
  validation_method         = "DNS"
  subject_alternative_names = ["www.${local.my_domain}"]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "resume_distribution" {
  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  price_class = "PriceClass_100"

  aliases = ["www.${local.my_domain}", "${local.my_domain}"]

  default_cache_behavior {
    cache_policy_id  = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    target_origin_id = local.s3_origin_id
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.mydomain.arn
    ssl_support_method  = "sni-only"
  }
}