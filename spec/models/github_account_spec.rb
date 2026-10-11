require "rails_helper"

RSpec.describe GithubAccount do
  describe ".uid_for" do
    def stub_response(klass, code:, body: "")
      response = klass.new("1.1", code, "")
      allow(response).to receive(:body).and_return(body)
      allow(Net::HTTP).to receive(:get_response).and_return(response)
    end

    it "ログイン名を GitHub の数値 ID（文字列）に解決する" do
      stub_response(Net::HTTPOK, code: "200", body: { id: 583231, login: "octocat" }.to_json)

      expect(described_class.uid_for("octocat")).to eq("583231")
      expect(Net::HTTP).to have_received(:get_response)
        .with(URI("https://api.github.com/users/octocat"), hash_including("Accept"))
    end

    it "存在しないログイン名なら nil を返す" do
      stub_response(Net::HTTPNotFound, code: "404")

      expect(described_class.uid_for("no-such-user")).to be_nil
    end

    it "それ以外の応答なら LookupError にする" do
      stub_response(Net::HTTPForbidden, code: "403")

      expect { described_class.uid_for("octocat") }.to raise_error(GithubAccount::LookupError, /403/)
    end

    it "接続できなければ LookupError にする" do
      allow(Net::HTTP).to receive(:get_response).and_raise(SocketError, "getaddrinfo")

      expect { described_class.uid_for("octocat") }.to raise_error(GithubAccount::LookupError, /接続できません/)
    end
  end
end
