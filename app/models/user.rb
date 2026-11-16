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

  # 管理者 A と B が同時に互いを外すと、どちらも「実行者は管理者」の確認を通ったあとで更新し、0 人になりうる。
  # SQLite のトランザクションは Rails 8 から BEGIN IMMEDIATE で始まり書き込みが直列化されるので、
  # その中で実行者がまだ管理者かを確かめ直す。実行者（≠ 解除対象）が残るので、解除後も 1 人以上残る
  def revoke_admin_by(actor)
    self.class.transaction do
      next false unless self.class.exists?(id: actor.id, admin: true)

      update!(admin: false)
      true
    end
  end
end
