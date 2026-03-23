module Admin
  module DashboardHelper
    KPI_CARD_DEFINITIONS = [
      { key: "total_customers", title: "Total Customers", icon: "ti-users", tone: "primary", note: "Registered loyalty members" },
      { key: "active_customers", title: "Active Customers", icon: "ti-user-heart", tone: "success", note: "Visited in the last 30 days" },
      { key: "total_transactions", title: "Total Transactions", icon: "ti-receipt-2", tone: "info", note: "Fuel visits in range" },
      { key: "total_revenue", title: "Total Revenue", icon: "ti-currency-rupee", tone: "warning", note: "Gross fuel sales split by fuel type" },
      { key: "points_issued", title: "Points Issued", icon: "ti-badge", tone: "primary", note: "Earned loyalty points" },
      { key: "points_redeemed", title: "Points Redeemed", icon: "ti-gift-card", tone: "danger", note: "Redeemed points value" },
      { key: "avg_spend_per_visit", title: "Average Spend per Visit", icon: "ti-coins", tone: "info", note: "Average transaction value" },
      { key: "visits_per_customer", title: "Visits per Customer", icon: "ti-route", tone: "success", note: "Average visits per engaged customer" }
    ].freeze

    CHART_CARD_DEFINITIONS = [
      { key: "transactions_trend", title: "Transactions Trend", subtitle: "Daily transaction count across the selected period.", kind: "line" },
      { key: "revenue_trend", title: "Revenue Trend", subtitle: "Daily fuel revenue for the selected period.", kind: "line" },
      { key: "points_trend", title: "Points Issued vs Redeemed", subtitle: "Loyalty points earned and redeemed over time.", kind: "line" },
      { key: "active_users_trend", title: "Active Users Trend", subtitle: "Distinct customers transacting each day.", kind: "line" },
      { key: "repeat_vs_new", title: "Repeat vs New Customers", subtitle: "Customer mix based on first-ever visit date.", kind: "bar" },
      { key: "visits_distribution", title: "Visits Distribution", subtitle: "How often customers returned in the selected period.", kind: "bar" },
      { key: "top_rewards_redeemed", title: "Top Redemption Slabs", subtitle: "Most-used redemption values in 100-point steps.", kind: "bar", horizontal: true },
      { key: "transactions_by_hour", title: "Transactions by Hour", subtitle: "Hourly demand pattern to help plan staffing and queues.", kind: "bar" },
      { key: "transactions_by_day", title: "Transactions by Day of Week", subtitle: "Weekly traffic pattern for your station.", kind: "bar" }
    ].freeze

    CUSTOMER_LEADERBOARD_DEFINITIONS = [
      { key: "top_customers_by_transactions", title: "Top 5 Customers by Visits", subtitle: "Highest-visit customers in the selected period." },
      { key: "top_customers_by_revenue", title: "Top 5 Customers by Spend", subtitle: "Highest-spend customers in the selected period." }
    ].freeze

    def dashboard_kpi_cards
      KPI_CARD_DEFINITIONS
    end

    def dashboard_chart_cards
      CHART_CARD_DEFINITIONS
    end

    def dashboard_customer_leaderboards
      CUSTOMER_LEADERBOARD_DEFINITIONS
    end
  end
end
