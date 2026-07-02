require "test_helper"

class Api::V1::PricingServiceTest < ActiveSupport::TestCase
  test "returns cached rate on repeated request for same hotel/room/period" do
    memory_store = ActiveSupport::Cache::MemoryStore.new
    fetch_count = 0

    Rails.stub(:cache, memory_store) do
      stub_response = ->(**_) {
        fetch_count += 1
        { "rate" => "73700" }
      }

      Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      assert_equal 1, fetch_count, "expected upstream fetch once and second call to be served from cache"
    end
  end

  test "uses different cache keys for different rooms" do
    memory_store = ActiveSupport::Cache::MemoryStore.new
    fetch_count = 0

    Rails.stub(:cache, memory_store) do
      stub_response = ->(**_) {
        fetch_count += 1
        { "rate" => "73700" }
      }

      Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "DoubleRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      assert_equal 2, fetch_count, "expected distinct room values to generate distinct cache keys"
    end
  end

  test "marks invalid and records error on faraday timeout" do
    memory_store = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, memory_store) do
      Faraday.stub(:post, ->(*) { raise Faraday::TimeoutError }) do
        service = Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
        service.run

        assert_not service.valid?
        assert_includes service.errors.first, "timed out"
      end
    end
  end

  test "uses different cache keys for params containing slashes" do
    memory_store = ActiveSupport::Cache::MemoryStore.new
    fetch_count = 0

    Rails.stub(:cache, memory_store) do
      stub_response = ->(**_) {
        fetch_count += 1
        { "rate" => "73700" }
      }

      Api::V1::PricingService.new(period: "Summer", hotel: "Float/Point", room: "SingletonRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      Api::V1::PricingService.new(period: "Summer", hotel: "Float", room: "Point/SingletonRoom")
                             .tap { |s| s.stub(:fetch_from_upstream, stub_response) { s.run } }

      assert_equal 2, fetch_count, "params with slashes must not collide in the cache key"
    end
  end

  test "populates errors when upstream fails" do
    memory_store = ActiveSupport::Cache::MemoryStore.new

    Rails.stub(:cache, memory_store) do
      service = Api::V1::PricingService.new(period: "Summer", hotel: "FloatingPointResort", room: "SingletonRoom")
      service.stub(:fetch_from_upstream, -> { raise Api::V1::PricingService::UpstreamError, "Pricing model timed out." }) do
        service.run
      end

      assert_not service.valid?
      assert_includes service.errors.first, "timed out"
    end
  end
end
