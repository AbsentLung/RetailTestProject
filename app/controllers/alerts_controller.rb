class AlertsController < ApplicationController
  def index
    @alerts = paginate(Alert.includes(:brand, :product, :store).order(triggered_at: :desc))
  end

  def show
    @alert = Alert.includes(:brand, :product, :store, :first_event, :second_event).find(params[:id])
  end
end
