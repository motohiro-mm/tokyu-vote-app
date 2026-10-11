# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc
]

# 誰が何に投票したかは画面にも書き出しにも出さない方針（CategoryResult#comments_by）なので、
# リクエストログにも投票先とコメントを残さない
Rails.application.config.filter_parameters += [ :entry_id, :talk_id, :comment ]
