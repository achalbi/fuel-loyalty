module Analytics
  class EventsController < ApplicationController
    skip_forgery_protection only: :create

    def create
      analytics_event = AnalyticsEvent.new(
        name: analytics_event_params[:name],
        page_path: analytics_event_params[:page_path],
        properties: analytics_event_properties,
        user_agent: request.user_agent,
        user: current_user
      )

      if analytics_event.save
        head :accepted
      else
        render json: { errors: analytics_event.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    def analytics_event_params
      params.permit(:name, :page_path)
    end

    def analytics_event_properties
      raw_properties = params[:properties]
      return {} if raw_properties.blank?

      raw_properties.respond_to?(:to_unsafe_h) ? raw_properties.to_unsafe_h : raw_properties.to_h
    end
  end
end
