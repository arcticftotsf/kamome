Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :none
    policy.script_src      :self
    policy.style_src       :self
    policy.img_src         :self, :data
    policy.font_src        :self
    policy.connect_src     :self
    policy.form_action     :self
    policy.base_uri        :self
    policy.object_src      :none
    policy.frame_ancestors :none
  end

  # リクエストごとに新しい nonce を作る
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]

  config.content_security_policy_report_only = false
end
