require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_before_action :require_login

    def index
      render plain: "ok"
    end
  end

  context "APP_ENV_LABEL が未設定のとき（本番・ローカル）" do
    it "誰でもアクセスできる" do
      get :index
      expect(response).to have_http_status(:ok)
    end

    it "noindex ヘッダを付けない" do
      get :index
      expect(response.headers["X-Robots-Tag"]).to be_nil
    end
  end

  context "APP_ENV_LABEL=staging のとき（検証環境）" do
    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APP_ENV_LABEL").and_return("staging")
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("STAGING_BASIC_AUTH_PASSWORD").and_return("secret")
    end

    it "Basic 認証なしでは 401 を返す" do
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "パスワードが違えば 401 を返す" do
      request.env["HTTP_AUTHORIZATION"] =
        ActionController::HttpAuthentication::Basic.encode_credentials("staging", "wrong")
      get :index
      expect(response).to have_http_status(:unauthorized)
    end

    it "正しいパスワードならアクセスでき、noindex ヘッダが付く" do
      request.env["HTTP_AUTHORIZATION"] =
        ActionController::HttpAuthentication::Basic.encode_credentials("staging", "secret")
      get :index
      expect(response).to have_http_status(:ok)
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end
  end
end
