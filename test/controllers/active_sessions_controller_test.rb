require "test_helper"

class ActiveSessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as @user
  end

  test "index" do
    get active_sessions_url
    assert_response :success
  end

  test "ends another session of mine" do
    other = @user.sessions.create!
    assert_difference("Session.count", -1) do
      delete active_session_url(other)
    end
  end

  test "cannot end someone else's session" do
    foreign = users(:two).sessions.create!
    assert_no_difference("Session.count") do
      delete active_session_url(foreign)
    end
    assert_response :not_found
  end

  test "ends all other sessions" do
    @user.sessions.create!
    delete others_active_sessions_url
    assert_equal 1, @user.sessions.count
  end
end
