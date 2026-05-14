# ============================================================================
# MODULE: MONITORING - Centralized CloudWatch Monitoring
# ============================================================================
# Dashboard widgets remain local to the blueprint as a JSON template while
# alarm definitions are expressed in HCL for readability and reuse.
# ============================================================================

locals {
  np_segment = var.environment == "p" ? "" : "np-"
  alarm_base = "cw-${local.np_segment}${var.app_id}-${var.environment}"

  monitoring_dashboard_body = templatefile("${path.module}/../../monitoring/dashboard.json.tftpl", {
    region                  = var.region
    alb_arn_suffix          = module.alb.alb_arn_suffix
    target_group_arn_suffix = module.alb.target_group_arn_suffix
    asg_name                = module.asg.asg_name
    db_cluster_id           = module.aurora.cluster_id
  })

  monitoring_alarm_definitions = {
    unhealthy_targets = {
      alarm_name          = "${local.alarm_base}-unhealthy-targets"
      alarm_description   = "Alert when at least one target is unhealthy"
      comparison_operator = "GreaterThanOrEqualToThreshold"
      evaluation_periods  = 2
      metric_name         = "UnHealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Average"
      threshold           = 1
      treat_missing_data  = "notBreaching"
      dimensions = {
        LoadBalancer = module.alb.alb_arn_suffix
        TargetGroup  = module.alb.target_group_arn_suffix
      }
      tags = {
        Name        = "${local.alarm_base}-unhealthy-targets"
        Environment = var.environment
      }
    }

    high_ec2_cpu = {
      alarm_name          = "${local.alarm_base}-high-ec2-cpu"
      alarm_description   = "Alert when EC2 CPU utilization is high"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CPUUtilization"
      namespace           = "AWS/EC2"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      treat_missing_data  = "notBreaching"
      dimensions = {
        AutoScalingGroupName = module.asg.asg_name
      }
      tags = {
        Name        = "${local.alarm_base}-high-ec2-cpu"
        Environment = var.environment
      }
    }

    database_high_cpu = {
      alarm_name          = "${local.alarm_base}-database-high-cpu"
      alarm_description   = "Alert when database CPU utilization is high"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = 80
      treat_missing_data  = "notBreaching"
      dimensions = {
        DBClusterIdentifier = module.aurora.cluster_id
      }
      tags = {
        Name        = "${local.alarm_base}-database-high-cpu"
        Environment = var.environment
      }
    }

    high_database_connections = {
      alarm_name          = "${local.alarm_base}-high-database-connections"
      alarm_description   = "Alert when database connections exceed threshold"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "DatabaseConnections"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = var.database_connection_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        DBClusterIdentifier = module.aurora.cluster_id
      }
      tags = {
        Name        = "${local.alarm_base}-high-database-connections"
        Environment = var.environment
      }
    }
  }
}

module "monitoring" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/monitoring?ref=v1.0.0"

  app_id = var.app_id
  environment  = var.environment
  alert_email  = var.alert_email

  dashboard_body    = local.monitoring_dashboard_body
  alarm_definitions = local.monitoring_alarm_definitions

  tags = merge(
    var.tags,
    { Component = "Monitoring" }
  )

  depends_on = [
    module.alb,
    module.asg,
    module.aurora
  ]
}
