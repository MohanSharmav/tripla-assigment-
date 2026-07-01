require "test_helper"

class Api::V1::PricingControllerTest < ActionDispatch::IntegrationTest
  test "should get pricing with all parameters" do
    mock_result = { "rate" => "15000" }
    mock_service = Minitest::Mock.new
    mock_service.expect(:run, nil)
    mock_service.expect(:valid?, true)
    mock_service.expect(:result, mock_result)

    Api::V1::PricingService.stub(:new, mock_service) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel: "FloatingPointResort",
        room: "SingletonRoom"
      }

      assert_response :success
      assert_equal "application/json", @response.media_type

      json_response = JSON.parse(@response.body)
      assert_equal "15000", json_response["rate"]
    end
  end

  test "should return error when rate API fails" do
    mock_service = Minitest::Mock.new
    mock_service.expect(:run, nil)
    mock_service.expect(:valid?, false)
    mock_service.expect(:errors, ["Pricing model is currently unavailable."])

    Api::V1::PricingService.stub(:new, mock_service) do
      get api_v1_pricing_url, params: {
        period: "Summer",
        hotel: "FloatingPointResort",
        room: "SingletonRoom"
      }

      assert_response :service_unavailable
      assert_equal "application/json", @response.media_type

      json_response = JSON.parse(@response.body)
      assert_includes json_response["error"], "Pricing model is currently unavailable"
    end
  end

  test "should return error without any parameters" do
    get api_v1_pricing_url

    assert_response :bad_request
    assert_equal "application/json", @response.media_type

    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Missing required parameters"
  end

  test "should handle empty parameters" do
    get api_v1_pricing_url, params: {
      period: "",
      hotel: "",
      room: ""
    }

    assert_response :bad_request
    assert_equal "application/json", @response.media_type

    json_response = JSON.parse(@response.body)
    assert_includes json_response["error"], "Missing required parameters"
  end
end
