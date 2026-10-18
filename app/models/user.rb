class User < ApplicationRecord
  has_many :entries, dependent: :destroy
  has_many :votes, dependent: :destroy
  has_many :talk_votes, dependent: :destroy

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :name, presence: true

  # GitHub の nickname は変わりうるので、ログインのたびに name を更新する
  def self.find_or_create_from_auth_hash!(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.name = auth.info.nickname
    user.save!
    user
  end

  # ログインのたびにトークンを発行し、ハッシュだけを DB に残す。平文はセッションにしか無い
  def start_session!
    token = SecureRandom.urlsafe_base64
    update!(session_digest: BCrypt::Password.create(token))
    token
  end

  def authenticated?(token)
    return false if session_digest.blank? || token.blank?

    BCrypt::Password.new(session_digest).is_password?(token)
  end
end
