module Api
  module V1
    module Admin
      # F1 — campaign CRUD + preview / run / activate / pause. Admin-only.
      class CampaignsController < Api::V1::Admin::BaseController
        include CampaignParams

        before_action :set_campaign, only: %i[show update destroy preview run activate pause]

        def index
          authorize Campaign
          scope = Campaign.recent_first
          scope = scope.where(status: params[:status]) if Campaign.statuses.key?(params[:status].to_s)
          render json: { campaigns: scope.map { |c| CampaignSerializer.call(c) } }, status: :ok
        end

        def show
          authorize @campaign
          render json: CampaignSerializer.call(@campaign), status: :ok
        end

        def create
          authorize Campaign
          campaign = Campaign.new(created_by: current_user)
          assign_campaign(campaign, campaign_params)
          campaign.save!
          render json: CampaignSerializer.call(campaign), status: :created
        end

        def update
          authorize @campaign
          assign_campaign(@campaign, campaign_params)
          @campaign.save!
          render json: CampaignSerializer.call(@campaign), status: :ok
        end

        def destroy
          authorize @campaign
          @campaign.destroy!
          head :no_content
        end

        def preview
          authorize @campaign, :preview?
          result = Campaigns::Preview.call(@campaign)
          render json: { qualifying_count: result.qualifying_count, sample: result.sample, reachable: result.reachable }, status: :ok
        end

        def run
          authorize @campaign, :run?
          return render_error(status: 422, code: "campaign_not_active", message: "Activate the campaign before running it.") unless @campaign.active?

          notify = ActiveModel::Type::Boolean.new.cast(params.fetch(:notify, true))
          result = Campaigns::Runner.call(@campaign, notify: notify)
          render json: {
            qualified: result.qualified, rewarded: result.rewarded,
            notification_message_id: result.notification_message&.id, delivery: result.delivery,
          }, status: :ok
        end

        def activate
          authorize @campaign, :activate?
          @campaign.update!(status: :active)
          render json: CampaignSerializer.call(@campaign), status: :ok
        end

        def pause
          authorize @campaign, :pause?
          @campaign.update!(status: :paused)
          render json: CampaignSerializer.call(@campaign), status: :ok
        end

        private

        def set_campaign
          @campaign = Campaign.find(params[:id])
        end

        def campaign_params
          params.require(:campaign).permit(
            :name, :description, :reward_kind, :discount_amount, :discount_percent, :gift_description,
            :bonus_points, :min_purchase_amount, :min_purchase_litres, :period, :period_days,
            :window_start, :window_end, :target_type, :target_customer_type, :starts_at, :ends_at,
            channels: [], target_customer_ids: []
          )
        end
      end
    end
  end
end
