module Api::V1
  class PricingService < BaseService
    class UpstreamError < StandardError; end

    def initialize(period:, hotel:, room:)
      @period = period
      @hotel = hotel
      @room = room
    end

    def run
      cache_key = "rate_v1/#{@hotel}/#{@room}/#{@period}"
      @result = Rails.cache.fetch(cache_key, expires_in: 5.minutes, race_condition_ttl: 10.seconds) do
        fetch_from_upstream
      end
    rescue UpstreamError => e
      errors << e.message
    end

    private

    def fetch_from_upstream
      base_url = ENV.fetch("RATE_API_URL", "http://rate-api:8080")
      api_url = base_url.end_with?("/pricing") ? base_url : "#{base_url}/pricing"
      token = ENV.fetch("RATE_API_TOKEN", "04aa6f42aa03f220c2ae9a276cd68c62")

      response = Faraday.post(api_url) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["token"] = token
        req.body = { attributes: [{ period: @period, hotel: @hotel, room: @room }] }.to_json
        req.options.timeout = 2
        req.options.open_timeout = 1
      end

      unless response.success?
        Rails.logger.error("Pricing API Error: #{response.status} - #{response.body}")
        raise UpstreamError, "Pricing model is currently unavailable."
      end

      JSON.parse(response.body)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed
      Rails.logger.error("Pricing API Timeout")
      raise UpstreamError, "Pricing model timed out."
    end
  end
end
