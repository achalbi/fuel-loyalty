module Admin
  # F1 — campaign management (web): CRUD + preview / run / activate / pause.
  class CampaignsController < BaseController
    include CampaignParams

    before_action :set_campaign, only: %i[show edit update destroy preview run activate pause]

    def index
      authorize Campaign
      @campaigns = Campaign.recent_first.to_a
    end

    def show
      authorize @campaign
      @preview = nil
    end

    def new
      authorize Campaign
      @campaign = Campaign.new(reward_kind: :bonus_points, period: :rolling_days, period_days: 30,
                               target_type: :all, channels: "push")
      load_form_options
    end

    def create
      authorize Campaign
      @campaign = Campaign.new(created_by: current_user)
      assign_campaign(@campaign, campaign_params)
      if @campaign.save
        redirect_to admin_campaign_path(@campaign), notice: "Campaign created."
      else
        load_form_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @campaign
      load_form_options
    end

    def update
      authorize @campaign
      assign_campaign(@campaign, campaign_params)
      if @campaign.save
        redirect_to admin_campaign_path(@campaign), notice: "Campaign updated."
      else
        load_form_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @campaign
      @campaign.destroy!
      redirect_to admin_campaigns_path, notice: "Campaign deleted."
    end

    def preview
      authorize @campaign, :preview?
      @preview = Campaigns::Preview.call(@campaign)
      render :show
    end

    def run
      authorize @campaign, :run?
      return redirect_to admin_campaign_path(@campaign), alert: "Activate the campaign before running it." unless @campaign.active?

      result = Campaigns::Runner.call(@campaign, notify: params[:notify] != "false")
      redirect_to admin_campaign_path(@campaign),
        notice: "Ran campaign — #{result.qualified} qualified, #{result.rewarded} rewarded."
    end

    def activate
      authorize @campaign, :activate?
      @campaign.update!(status: :active)
      redirect_to admin_campaign_path(@campaign), notice: "Campaign activated."
    end

    def pause
      authorize @campaign, :pause?
      @campaign.update!(status: :paused)
      redirect_to admin_campaign_path(@campaign), notice: "Campaign paused."
    end

    private

    def set_campaign
      @campaign = Campaign.find(params[:id])
    end

    def load_form_options
      @customers = Customer.active.order(:name).limit(500).to_a
      @customer_types = Customer.customer_types.keys
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
