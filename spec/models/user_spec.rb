require "rails_helper"

RSpec.describe User do
  describe ".find_or_create_from_auth_hash!" do
    let(:auth) { OmniAuth::AuthHash.new(provider: "github", uid: "1", info: { nickname: "alice" }) }

    it "provider と uid で引き、無ければ作る" do
      expect { described_class.find_or_create_from_auth_hash!(auth) }.to change(described_class, :count).by(1)
      expect { described_class.find_or_create_from_auth_hash!(auth) }.not_to change(described_class, :count)
    end

    it "nickname が無ければ作らない" do
      auth.info.nickname = nil

      expect { described_class.find_or_create_from_auth_hash!(auth) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe "#start_session! / #authenticated?" do
    let(:user) { create(:user) }

    it "発行したトークンだけを受け付ける" do
      token = user.start_session!

      expect(user.authenticated?(token)).to be true
      expect(user.authenticated?("other")).to be false
      expect(user.authenticated?(nil)).to be false
    end

    it "平文のトークンを DB に残さない" do
      token = user.start_session!

      expect(user.session_digest).not_to include(token)
    end

    it "再発行すると前のトークンは使えなくなる" do
      old_token = user.start_session!
      user.start_session!

      expect(user.authenticated?(old_token)).to be false
    end

    it "トークンを発行していなければ何も受け付けない" do
      expect(user.authenticated?("anything")).to be false
    end
  end

  describe "#revoke_admin_by" do
    let(:actor) { create(:user, :admin) }
    let(:target) { create(:user, :admin) }

    it "実行者が管理者なら解除する" do
      expect(target.revoke_admin_by(actor)).to be true
      expect(target.reload).not_to be_admin
    end

    it "実行者が先に解除されていたら解除しない（互いを同時に解除して 0 人になるのを防ぐ）" do
      described_class.find(actor.id).update!(admin: false)

      expect(target.revoke_admin_by(actor)).to be false
      expect(target.reload).to be_admin
    end
  end
end
