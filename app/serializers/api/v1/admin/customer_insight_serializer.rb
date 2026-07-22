module Api
  module V1
    module Admin
      # E3/E5 — formats an Admin::Crm::CustomerInsight hash for JSON (dates → ISO).
      class CustomerInsightSerializer
        def self.call(insight)
          data = insight.to_h
          data.merge(
            first_visited_on: data[:first_visited_on]&.iso8601,
            last_visited_on: data[:last_visited_on]&.iso8601,
            expected_next_visit_on: data[:expected_next_visit_on]&.iso8601,
            contacts: contacts_json(data[:contacts]),
          )
        end

        def self.contacts_json(contacts)
          contacts.merge(last_contacted_at: contacts[:last_contacted_at]&.iso8601)
        end
      end
    end
  end
end
