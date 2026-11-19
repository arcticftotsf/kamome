require "test_helper"

class LockoutTest < ActionDispatch::IntegrationTest
  test "locks the account after repeated failures" do
    user = users(:one)
    5.times do
      post session_url, params: { email_address: user.email_address, password: "wrong-password" }
    end
    assert user.reload.locked?

    # ロック後は、正しいパスワードでも入れない
    assert_no_difference("Session.count") do
      post session_url, params: { email_address: user.email_address, password: "password" }
    end
    assert_redirected_to new_session_url
  end

  test "unlock! restores login" do
    user = users(:one)
    user.lock!
    user.unlock!
    assert_difference("Session.count", 1) do
      post session_url, params: { email_address: user.email_address, password: "password" }
    end
  end

  test "failed login is recorded in the audit log" do
    assert_difference("AuditLog.count", 1) do
      post session_url, params: { email_address: users(:one).email_address, password: "wrong-password" }
    end
    assert_equal "login_failed", AuditLog.order(:id).last.event
  end

  test "audit logs cannot be modified" do
    log = AuditLog.record("test_event", user: users(:one))
    assert_raises(ActiveRecord::ReadOnlyRecord) { log.update!(event: "changed") }
  end
end
