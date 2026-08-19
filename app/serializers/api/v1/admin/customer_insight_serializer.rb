module Api
  module V1
    module Admin
      # E3/E5 — formats an Admin::Crm::CustomerInsight hash for JSON (dates → ISO,
      # commercial metrics → plain numbers so a decimal never ships as a string).
      class CustomerInsightSerializer
        def self.call(insight)
          data = insight.to_h
          json = data.merge(
            first_visited_on: data[:first_visited_on]&.iso8601,
            last_visited_on: data[:last_visited_on]&.iso8601,
            expected_next_visit_on: data[:expected_next_visit_on]&.iso8601,
            metrics: metrics_json(data[:metrics]),
            contacts: contacts_json(data[:contacts]),
          )
          json[:lifetime_metrics] = metrics_json(data[:lifetime_metrics]) if data.key?(:lifetime_metrics)
          json
        end

        def self.metrics_json(metrics)
          metrics&.transform_values { |value| value.is_a?(Integer) ? value : value.to_f }
        end

        def self.contacts_json(contacts)
          contacts.merge(last_contacted_at: contacts[:last_contacted_at]&.iso8601)
        end
      end
    end
  end
end
