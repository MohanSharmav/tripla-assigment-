module Api
  module V1
    class PricingController < ApplicationController
      def index
        if params[:period].blank? || params[:hotel].blank? || params[:room].blank?
          return render json: { error: "Missing required parameters" }, status: :bad_request
        end

        service = Api::V1::PricingService.new(
          period: params[:period],
          hotel: params[:hotel],
          room: params[:room]
        )
        service.run

        if service.valid?
          render json: service.result, status: :ok
        else
          render json: { error: service.errors.first }, status: :service_unavailable
        end
      end
    end
  end
end
