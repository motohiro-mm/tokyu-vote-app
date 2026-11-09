require "rails_helper"

RSpec.describe "Content Security Policy", type: :request do
  let(:user) { create(:user) }
  let!(:event) { create(:event, status: :open) }

  before { sign_in(user) }

  it "report-only で CSP ヘッダを返し、script-src は self と nonce、style-src はそれに Google Fonts を足したものだけを許す" do
    get event_path(event)

    header = response.headers["Content-Security-Policy-Report-Only"]
    expect(header).to include("default-src 'self'")
    expect(header).to include("object-src 'none'")
    expect(header).to match(/script-src 'self' 'nonce-[^']+'/)
    expect(header).to match(%r{style-src 'self' https://fonts.googleapis.com 'nonce-[^']+'})
    expect(header).to include("font-src 'self' https://fonts.gstatic.com")
    expect(response.headers["Content-Security-Policy"]).to be_nil
  end

  it "importmap のインラインスクリプトにヘッダと同じ nonce が付く" do
    get event_path(event)

    nonce = response.headers["Content-Security-Policy-Report-Only"][/'nonce-([^']+)'/, 1]
    expect(response.body).to include(%(<script type="importmap" data-turbo-track="reload" nonce="#{nonce}">))
    expect(response.body).to include(%(<meta name="csp-nonce" content="#{nonce}"))
  end

  it "nonce はリクエストごとに変わる" do
    get event_path(event)
    first = response.headers["Content-Security-Policy-Report-Only"][/'nonce-([^']+)'/, 1]
    get event_path(event)
    second = response.headers["Content-Security-Policy-Report-Only"][/'nonce-([^']+)'/, 1]

    expect(first).not_to eq(second)
  end
end
