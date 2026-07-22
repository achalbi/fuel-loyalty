module Api
  module V1
    # E7 — customer feedback (rating + comment). Shared by the admin and staff APIs.
    class CustomerFeedbackSerializer
      def self.call(feedback)
        {
          id: feedback.id,
          customer_id: feedback.customer_id,
          rating: feedback.rating,
          comment: feedback.comment,
          source: feedback.source,
          source_label: feedback.source_label,
          transaction_id: feedback.transaction_id,
          visit_entry_id: feedback.visit_entry_id,
          recorded_by: feedback.recorded_by&.display_name,
          created_at: feedback.created_at.iso8601,
        }
      end

      # A list plus its rollup (count + average), the shape both feedback index
      # endpoints return.
      def self.collection(scope)
        feedbacks = scope.to_a
        avg = feedbacks.empty? ? nil : (feedbacks.sum(&:rating).to_f / feedbacks.size).round(2)
        {
          feedbacks: feedbacks.map { |feedback| call(feedback) },
          count: feedbacks.size,
          avg_rating: avg,
        }.compact
      end
    end
  end
end
