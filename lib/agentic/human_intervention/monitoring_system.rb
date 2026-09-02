# frozen_string_literal: true

require "monitor"
require "json"
require "net/http"
require "uri"

module Agentic
  module HumanIntervention
    # Real-time monitoring and alerting system for human intervention portal
    #
    # Provides comprehensive monitoring capabilities including:
    # - Event detection and threshold-based alerting
    # - SLA monitoring for response times and volumes
    # - Real-time notifications via multiple channels
    # - Performance metrics and health monitoring
    # - Integration with existing ObservabilityEngine
    #
    # Design Goals:
    # 1. Real-time event processing with minimal latency
    # 2. Flexible alerting rules and notification channels
    # 3. SLA compliance monitoring and reporting
    # 4. Integration with existing architectural patterns
    # 5. Scalable and resource-efficient implementation
    #
    # Architecture Integration:
    # - Uses Observer pattern for event subscription
    # - Integrates with ObservabilityEngine for unified events
    # - Follows performance optimization patterns from Performance module
    class MonitoringSystem
      # Alert severity levels
      module Severity
        INFO = :info
        WARNING = :warning
        CRITICAL = :critical
        EMERGENCY = :emergency
      end

      # Alert types for different monitoring scenarios
      module AlertType
        VOLUME_THRESHOLD = :volume_threshold      # Request volume alerts
        RESPONSE_TIME = :response_time           # SLA response time alerts
        QUEUE_BACKLOG = :queue_backlog          # Request backlog alerts
        ERROR_RATE = :error_rate                # System error rate alerts
        USER_ACTIVITY = :user_activity          # User activity alerts
        SYSTEM_HEALTH = :system_health          # System health alerts
        CUSTOM = :custom                        # Custom alert conditions
      end

      # Notification channels
      module Channel
        CONSOLE = :console
        FILE = :file
        EMAIL = :email
        SLACK = :slack
        WEBHOOK = :webhook
        SMS = :sms
      end

      # Alert rule definition
      class AlertRule
        attr_reader :id, :name, :type, :severity, :condition, :channels, :enabled, :metadata, :created_at
        attr_accessor :last_triggered_at, :trigger_count, :suppressed_until

        def initialize(name:, type:, condition:, severity: Severity::WARNING, channels: [Channel::CONSOLE], enabled: true, metadata: {})
          @id = SecureRandom.uuid
          @name = name
          @type = type
          @severity = severity
          @condition = condition.freeze
          @channels = channels.freeze
          @enabled = enabled
          @metadata = metadata.freeze
          @created_at = Time.now
          @last_triggered_at = nil
          @trigger_count = 0
          @suppressed_until = nil
        end

        # Check if rule should trigger based on current metrics
        # @param metrics [Hash] Current system metrics
        # @return [Boolean] True if rule should trigger
        def should_trigger?(metrics)
          return false unless @enabled
          return false if suppressed?

          evaluate_condition(metrics)
        end

        # Check if rule is currently suppressed
        # @return [Boolean] True if rule is suppressed
        def suppressed?
          @suppressed_until && Time.now < @suppressed_until
        end

        # Suppress rule for specified duration
        # @param duration [Integer] Suppression duration in seconds
        def suppress!(duration)
          @suppressed_until = Time.now + duration
        end

        # Record rule trigger
        def record_trigger!
          @last_triggered_at = Time.now
          @trigger_count += 1
        end

        # Convert to hash for serialization
        # @return [Hash] Hash representation
        def to_h
          {
            id: @id,
            name: @name,
            type: @type,
            severity: @severity,
            condition: @condition,
            channels: @channels,
            enabled: @enabled,
            metadata: @metadata,
            created_at: @created_at.iso8601,
            last_triggered_at: @last_triggered_at&.iso8601,
            trigger_count: @trigger_count,
            suppressed_until: @suppressed_until&.iso8601,
            suppressed: suppressed?
          }
        end

        private

        # Evaluate alert condition against metrics
        # @param metrics [Hash] Current metrics
        # @return [Boolean] True if condition is met
        def evaluate_condition(metrics)
          case @type
          when AlertType::VOLUME_THRESHOLD
            threshold = @condition[:threshold] || 50
            current_volume = metrics[:active_requests] || 0
            current_volume >= threshold
          when AlertType::RESPONSE_TIME
            sla_threshold = @condition[:sla_seconds] || 3600
            current_avg = metrics[:average_response_time] || 0
            current_avg > sla_threshold
          when AlertType::QUEUE_BACKLOG
            backlog_threshold = @condition[:backlog_threshold] || 25
            pending_count = metrics[:pending_requests] || 0
            pending_count >= backlog_threshold
          when AlertType::ERROR_RATE
            error_threshold = @condition[:error_rate_threshold] || 0.05
            current_error_rate = metrics[:error_rate] || 0.0
            current_error_rate > error_threshold
          when AlertType::SYSTEM_HEALTH
            health_status = metrics[:health_status]
            critical_states = @condition[:critical_states] || [:critical, :overloaded, :degraded]
            critical_states.include?(health_status)
          when AlertType::CUSTOM
            # Custom condition evaluation
            condition_proc = @condition[:evaluator]
            condition_proc ? condition_proc.call(metrics) : false
          else
            false
          end
        end
      end

      # Alert instance representing a triggered alert
      class Alert
        attr_reader :id, :rule_id, :rule_name, :severity, :message, :metrics_snapshot, :created_at, :acknowledged_at, :resolved_at

        def initialize(rule:, message:, metrics_snapshot: {})
          @id = SecureRandom.uuid
          @rule_id = rule.id
          @rule_name = rule.name
          @severity = rule.severity
          @message = message
          @metrics_snapshot = metrics_snapshot.freeze
          @created_at = Time.now
          @acknowledged_at = nil
          @resolved_at = nil
        end

        # Acknowledge alert
        # @param user [String] User acknowledging the alert
        def acknowledge!(user = "system")
          @acknowledged_at = Time.now
          @acknowledged_by = user
        end

        # Resolve alert
        # @param user [String] User resolving the alert
        # @param comment [String] Resolution comment
        def resolve!(user = "system", comment: nil)
          @resolved_at = Time.now
          @resolved_by = user
          @resolution_comment = comment
        end

        # Check if alert is active (not resolved)
        # @return [Boolean] True if alert is active
        def active?
          @resolved_at.nil?
        end

        # Get alert age in seconds
        # @return [Float] Age in seconds
        def age
          Time.now - @created_at
        end

        # Convert to hash for serialization
        # @return [Hash] Hash representation
        def to_h
          {
            id: @id,
            rule_id: @rule_id,
            rule_name: @rule_name,
            severity: @severity,
            message: @message,
            metrics_snapshot: @metrics_snapshot,
            created_at: @created_at.iso8601,
            acknowledged_at: @acknowledged_at&.iso8601,
            acknowledged_by: @acknowledged_by,
            resolved_at: @resolved_at&.iso8601,
            resolved_by: @resolved_by,
            resolution_comment: @resolution_comment,
            active: active?,
            age: age
          }
        end
      end

      # Notification dispatcher for sending alerts through various channels
      class NotificationDispatcher
        def initialize
          @handlers = {}
          setup_default_handlers
        end

        # Send notification through specified channels
        # @param alert [Alert] Alert to send
        # @param channels [Array<Symbol>] Channels to send through
        def send_notification(alert, channels)
          channels.each do |channel|
            handler = @handlers[channel]
            next unless handler

            begin
              handler.call(alert)
            rescue => e
              puts "Notification error for #{channel}: #{e.message}" if $DEBUG
            end
          end
        end

        # Register custom notification handler
        # @param channel [Symbol] Channel identifier
        # @param handler [Proc] Notification handler
        def register_handler(channel, &handler)
          @handlers[channel] = handler if handler
        end

        private

        # Setup default notification handlers
        def setup_default_handlers
          # Console notification
          @handlers[Channel::CONSOLE] = ->(alert) do
            severity_color = case alert.severity
            when Severity::INFO then :blue
            when Severity::WARNING then :yellow
            when Severity::CRITICAL then :red
            when Severity::EMERGENCY then :red
            else :white
            end

            timestamp = alert.created_at.strftime("%Y-%m-%d %H:%M:%S")
            severity_text = alert.severity.to_s.upcase

            puts UI.colorize("[#{timestamp}] #{severity_text}: #{alert.message}", severity_color)
          end

          # File notification
          @handlers[Channel::FILE] = ->(alert) do
            log_dir = File.join(Dir.home, ".agentic", "logs")
            FileUtils.mkdir_p(log_dir) unless File.directory?(log_dir)

            log_file = File.join(log_dir, "alerts.log")
            timestamp = alert.created_at.strftime("%Y-%m-%d %H:%M:%S")
            severity_text = alert.severity.to_s.upcase

            File.open(log_file, "a") do |f|
              f.puts "[#{timestamp}] #{severity_text}: #{alert.message}"
              f.puts "  Rule: #{alert.rule_name} (#{alert.rule_id})"
              f.puts "  Metrics: #{JSON.generate(alert.metrics_snapshot)}"
              f.puts
            end
          end

          # Webhook notification
          @handlers[Channel::WEBHOOK] = ->(alert) do
            webhook_url = ENV["AGENTIC_WEBHOOK_URL"]
            return unless webhook_url

            payload = {
              alert: alert.to_h,
              timestamp: alert.created_at.iso8601,
              source: "agentic-human-intervention"
            }

            uri = URI.parse(webhook_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true if uri.scheme == "https"

            request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
            request.body = JSON.generate(payload)

            http.request(request)
          end

          # Email notification (placeholder)
          @handlers[Channel::EMAIL] = ->(alert) do
            # Email implementation would integrate with SMTP or email service
            puts "Email notification: #{alert.message}" if $DEBUG
          end

          # Slack notification (placeholder)
          @handlers[Channel::SLACK] = ->(alert) do
            # Slack implementation would use Slack API
            slack_webhook = ENV["SLACK_WEBHOOK_URL"]
            return unless slack_webhook

            color = case alert.severity
            when Severity::INFO then "good"
            when Severity::WARNING then "warning"
            when Severity::CRITICAL then "danger"
            when Severity::EMERGENCY then "danger"
            end

            payload = {
              text: "Human Intervention Alert",
              attachments: [{
                color: color,
                fields: [
                  {title: "Severity", value: alert.severity.to_s.upcase, short: true},
                  {title: "Rule", value: alert.rule_name, short: true},
                  {title: "Message", value: alert.message, short: false}
                ],
                ts: alert.created_at.to_i
              }]
            }

            uri = URI.parse(slack_webhook)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
            request.body = JSON.generate(payload)

            http.request(request)
          end
        end
      end

      # SLA monitoring for tracking compliance and performance
      class SLAMonitor
        DEFAULT_SLAS = {
          critical_requests: {response_time: 1800, availability: 0.99},    # 30 minutes, 99%
          high_priority: {response_time: 3600, availability: 0.95},       # 1 hour, 95%
          normal_priority: {response_time: 7200, availability: 0.90},     # 2 hours, 90%
          low_priority: {response_time: 86400, availability: 0.85}        # 24 hours, 85%
        }.freeze

        def initialize(slas = DEFAULT_SLAS)
          @slas = slas
          @metrics_history = []
          @mutex = Mutex.new
        end

        # Record metrics for SLA tracking
        # @param metrics [Hash] Current metrics snapshot
        def record_metrics(metrics)
          @mutex.synchronize do
            @metrics_history << {
              timestamp: Time.now,
              metrics: metrics.dup
            }

            # Keep only last 24 hours of metrics
            cutoff = Time.now - 86400
            @metrics_history.reject! { |entry| entry[:timestamp] < cutoff }
          end
        end

        # Check SLA compliance for time period
        # @param period_hours [Integer] Period in hours to check
        # @return [Hash] SLA compliance report
        def check_compliance(period_hours = 24)
          @mutex.synchronize do
            cutoff = Time.now - (period_hours * 3600)
            relevant_metrics = @metrics_history.select { |entry| entry[:timestamp] >= cutoff }

            return empty_compliance_report if relevant_metrics.empty?

            calculate_sla_compliance(relevant_metrics)
          end
        end

        # Get SLA violations in time period
        # @param period_hours [Integer] Period in hours to check
        # @return [Array<Hash>] List of SLA violations
        def get_violations(period_hours = 24)
          compliance = check_compliance(period_hours)

          violations = []

          compliance.each do |sla_name, sla_data|
            if sla_data[:response_time_compliance] < @slas[sla_name][:availability]
              violations << {
                sla: sla_name,
                type: :response_time,
                target: @slas[sla_name][:availability],
                actual: sla_data[:response_time_compliance],
                severity: calculate_violation_severity(sla_data[:response_time_compliance])
              }
            end

            if sla_data[:availability] < @slas[sla_name][:availability]
              violations << {
                sla: sla_name,
                type: :availability,
                target: @slas[sla_name][:availability],
                actual: sla_data[:availability],
                severity: calculate_violation_severity(sla_data[:availability])
              }
            end
          end

          violations
        end

        private

        # Calculate SLA compliance from metrics history
        def calculate_sla_compliance(metrics_history)
          compliance = {}

          @slas.each do |sla_name, sla_config|
            total_samples = metrics_history.size
            compliant_samples = metrics_history.count do |entry|
              avg_response_time = entry[:metrics][:average_response_time] || 0
              avg_response_time <= sla_config[:response_time]
            end

            compliance[sla_name] = {
              response_time_compliance: compliant_samples.to_f / total_samples,
              availability: calculate_availability(metrics_history),
              target_response_time: sla_config[:response_time],
              target_availability: sla_config[:availability],
              sample_count: total_samples
            }
          end

          compliance
        end

        # Calculate system availability from metrics
        def calculate_availability(metrics_history)
          return 1.0 if metrics_history.empty?

          operational_samples = metrics_history.count do |entry|
            health_status = entry[:metrics][:health_status]
            [:healthy, :warning].include?(health_status)
          end

          operational_samples.to_f / metrics_history.size
        end

        # Calculate violation severity
        def calculate_violation_severity(actual_value)
          case actual_value
          when 0.0..0.8 then Severity::EMERGENCY
          when 0.8..0.9 then Severity::CRITICAL
          when 0.9..0.95 then Severity::WARNING
          else Severity::INFO
          end
        end

        # Return empty compliance report
        def empty_compliance_report
          @slas.transform_values do |sla_config|
            {
              response_time_compliance: 0.0,
              availability: 0.0,
              target_response_time: sla_config[:response_time],
              target_availability: sla_config[:availability],
              sample_count: 0
            }
          end
        end
      end

      attr_reader :alert_rules, :active_alerts, :notification_dispatcher, :sla_monitor

      def initialize(portal = nil)
        @portal = portal
        @alert_rules = {}
        @active_alerts = {}
        @notification_dispatcher = NotificationDispatcher.new
        @sla_monitor = SLAMonitor.new
        @running = false
        @monitor_thread = nil
        @mutex = Monitor.new

        setup_default_alert_rules
        setup_observability_integration
      end

      # Start monitoring system
      def start!
        return false if @running

        @running = true
        @monitor_thread = Thread.new do
          Thread.current.name = "monitoring-loop"
          monitoring_loop
        end

        Agentic.logger&.info("Human Intervention Monitoring System started")
        true
      end

      # Stop monitoring system
      def stop!
        @running = false
        @monitor_thread&.join(5) # Wait up to 5 seconds

        Agentic.logger&.info("Human Intervention Monitoring System stopped")
        true
      end

      # Add alert rule
      # @param rule [AlertRule] Alert rule to add
      # @return [AlertRule] Added rule
      def add_alert_rule(rule)
        @mutex.synchronize do
          @alert_rules[rule.id] = rule
        end
        rule
      end

      # Remove alert rule
      # @param rule_id [String] Rule ID to remove
      # @return [Boolean] True if rule was removed
      def remove_alert_rule(rule_id)
        @mutex.synchronize do
          !@alert_rules.delete(rule_id).nil?
        end
      end

      # Get alert rule by ID
      # @param rule_id [String] Rule ID
      # @return [AlertRule, nil] Alert rule or nil
      def get_alert_rule(rule_id)
        @alert_rules[rule_id]
      end

      # List alert rules
      # @param enabled_only [Boolean] Show only enabled rules
      # @return [Array<AlertRule>] List of alert rules
      def list_alert_rules(enabled_only: false)
        rules = @alert_rules.values
        rules = rules.select(&:enabled) if enabled_only
        rules.sort_by(&:created_at)
      end

      # Acknowledge alert
      # @param alert_id [String] Alert ID
      # @param user [String] User acknowledging
      # @return [Boolean] True if acknowledged
      def acknowledge_alert(alert_id, user = "system")
        alert = @active_alerts[alert_id]
        return false unless alert

        alert.acknowledge!(user)
        true
      end

      # Resolve alert
      # @param alert_id [String] Alert ID
      # @param user [String] User resolving
      # @param comment [String] Resolution comment
      # @return [Boolean] True if resolved
      def resolve_alert(alert_id, user = "system", comment: nil)
        alert = @active_alerts[alert_id]
        return false unless alert

        alert.resolve!(user, comment: comment)
        @active_alerts.delete(alert_id)
        true
      end

      # Get active alerts
      # @param severity [Symbol] Filter by severity
      # @return [Array<Alert>] List of active alerts
      def get_active_alerts(severity: nil)
        alerts = @active_alerts.values
        alerts = alerts.select { |alert| alert.severity == severity } if severity
        alerts.sort_by(&:created_at).reverse
      end

      # Get monitoring statistics
      # @return [Hash] Monitoring statistics
      def monitoring_statistics
        @mutex.synchronize do
          {
            alert_rules: {
              total: @alert_rules.size,
              enabled: @alert_rules.values.count(&:enabled),
              disabled: @alert_rules.values.count { |rule| !rule.enabled }
            },
            active_alerts: {
              total: @active_alerts.size,
              by_severity: @active_alerts.values.group_by(&:severity).transform_values(&:size)
            },
            sla_compliance: @sla_monitor.check_compliance(24),
            system_status: @running ? :running : :stopped
          }
        end
      end

      # Check system health and generate health report
      # @return [Hash] Health report
      def health_report
        @portal&.stats || {}
        portal_health = @portal&.health_check || {status: :unknown}

        {
          monitoring_system: {
            status: @running ? :healthy : :stopped,
            alert_rules: @alert_rules.size,
            active_alerts: @active_alerts.size
          },
          portal_health: portal_health,
          sla_compliance: @sla_monitor.check_compliance(1), # Last hour
          recent_violations: @sla_monitor.get_violations(1)
        }
      end

      private

      # Main monitoring loop
      def monitoring_loop
        while @running
          begin
            check_alerts
            update_sla_metrics
            cleanup_old_alerts

            interruptible_sleep(30) # Check every 30 seconds
          rescue => e
            Agentic.logger&.error("Monitoring loop error: #{e.message}")
            interruptible_sleep(60) # Wait longer on error
          end
        end
      end

      # Sleep in small increments so stop! is not delayed by long intervals
      # @param duration [Numeric] Total time to sleep in seconds
      def interruptible_sleep(duration)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + duration
        while @running
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          break if remaining <= 0
          sleep([0.1, remaining].min)
        end
      end

      # Check all alert rules and trigger alerts if needed
      def check_alerts
        return unless @portal

        current_metrics = gather_current_metrics

        @alert_rules.values.each do |rule|
          next unless rule.should_trigger?(current_metrics)

          # Avoid duplicate alerts within cooldown period
          next if recent_alert_for_rule?(rule.id, 300) # 5 minute cooldown

          trigger_alert(rule, current_metrics)
        end
      end

      # Gather current system metrics
      def gather_current_metrics
        portal_stats = @portal&.stats || {}
        portal_health = @portal&.health_check || {}

        {
          active_requests: portal_stats[:active_requests] || 0,
          pending_requests: portal_stats[:pending_requests] || 0,
          total_requests: portal_stats[:total_requests] || 0,
          approved: portal_stats[:approved] || 0,
          rejected: portal_stats[:rejected] || 0,
          expired_requests: portal_stats[:expired_requests] || 0,
          average_response_time: portal_stats[:average_response_time] || 0.0,
          registered_users: portal_stats[:registered_users] || 0,
          health_status: portal_health[:status] || :unknown,
          error_rate: calculate_error_rate(portal_stats),
          timestamp: Time.now
        }
      end

      # Calculate current error rate
      def calculate_error_rate(stats)
        total = stats[:total_requests] || 0
        errors = (stats[:expired_requests] || 0) + (stats[:rejected] || 0)

        return 0.0 if total == 0
        errors.to_f / total
      end

      # Check if there was a recent alert for a rule
      def recent_alert_for_rule?(rule_id, cooldown_seconds)
        @active_alerts.values.any? do |alert|
          alert.rule_id == rule_id && alert.age < cooldown_seconds
        end
      end

      # Trigger an alert
      def trigger_alert(rule, metrics)
        message = generate_alert_message(rule, metrics)
        alert = Alert.new(rule: rule, message: message, metrics_snapshot: metrics)

        @mutex.synchronize do
          @active_alerts[alert.id] = alert
          rule.record_trigger!
        end

        @notification_dispatcher.send_notification(alert, rule.channels)

        Agentic.logger&.warn("Alert triggered: #{rule.name} - #{message}")
      end

      # Generate alert message based on rule and metrics
      def generate_alert_message(rule, metrics)
        case rule.type
        when AlertType::VOLUME_THRESHOLD
          threshold = rule.condition[:threshold]
          current = metrics[:active_requests]
          "High request volume: #{current} active requests (threshold: #{threshold})"
        when AlertType::RESPONSE_TIME
          threshold = rule.condition[:sla_seconds]
          current = metrics[:average_response_time].round(2)
          "SLA violation: Average response time #{current}s exceeds #{threshold}s"
        when AlertType::QUEUE_BACKLOG
          threshold = rule.condition[:backlog_threshold]
          current = metrics[:pending_requests]
          "Request backlog: #{current} pending requests (threshold: #{threshold})"
        when AlertType::SYSTEM_HEALTH
          status = metrics[:health_status]
          "System health degraded: Status is #{status}"
        else
          "Alert: #{rule.name}"
        end
      end

      # Update SLA monitoring metrics
      def update_sla_metrics
        return unless @portal

        current_metrics = gather_current_metrics
        @sla_monitor.record_metrics(current_metrics)
      end

      # Clean up old resolved alerts
      def cleanup_old_alerts
        @mutex.synchronize do
          cutoff = Time.now - 86400 # Keep alerts for 24 hours

          @active_alerts.reject! do |alert_id, alert|
            !alert.active? && alert.resolved_at && alert.resolved_at < cutoff
          end
        end
      end

      # Setup default alert rules
      def setup_default_alert_rules
        # High volume alert
        add_alert_rule(AlertRule.new(
          name: "High Request Volume",
          type: AlertType::VOLUME_THRESHOLD,
          condition: {threshold: 50},
          severity: Severity::WARNING,
          channels: [Channel::CONSOLE, Channel::FILE]
        ))

        # SLA violation alert
        add_alert_rule(AlertRule.new(
          name: "Response Time SLA Violation",
          type: AlertType::RESPONSE_TIME,
          condition: {sla_seconds: 3600},
          severity: Severity::CRITICAL,
          channels: [Channel::CONSOLE, Channel::FILE, Channel::WEBHOOK]
        ))

        # Queue backlog alert
        add_alert_rule(AlertRule.new(
          name: "Request Queue Backlog",
          type: AlertType::QUEUE_BACKLOG,
          condition: {backlog_threshold: 25},
          severity: Severity::WARNING,
          channels: [Channel::CONSOLE, Channel::FILE]
        ))

        # System health alert
        add_alert_rule(AlertRule.new(
          name: "System Health Degraded",
          type: AlertType::SYSTEM_HEALTH,
          condition: {critical_states: [:critical, :overloaded, :degraded]},
          severity: Severity::CRITICAL,
          channels: [Channel::CONSOLE, Channel::FILE, Channel::WEBHOOK]
        ))
      end

      # Setup integration with ObservabilityEngine
      def setup_observability_integration
        return unless defined?(Agentic) && Agentic.respond_to?(:observability_engine)

        # Register as observer for relevant events
        Agentic.observability_engine

        # This would integrate with the existing observability system
        # For now, it's a placeholder for future integration
      end
    end
  end
end
