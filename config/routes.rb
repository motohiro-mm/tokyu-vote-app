Rails.application.routes.draw do
  # 画像はログインが必要なエントリーフォームで受け付ける。Active Storage の直接アップロードを塞ぐ。
  scope ActiveStorage.routes_prefix do
    not_found = ->(_env) { [ 404, {}, [] ] }
    post "/direct_uploads", to: not_found
    put "/disk/:encoded_token", to: not_found
  end

  root "home#index"

  get "/login", to: "sessions#new"
  delete "/logout", to: "sessions#destroy"
  get "/mypage", to: "my_pages#show"
  # /auth/github への POST は OmniAuth のミドルウェアが受け、GitHub から戻ってきたらここに来る
  get "/auth/:provider/callback", to: "sessions#create", as: :auth_callback
  get "/auth/failure", to: "sessions#failure"

  get "/terms", to: "pages#terms"
  get "/privacy", to: "pages#privacy"

  resources :events, only: [ :show ], param: :slug do
    # resources より先に宣言しないと、categories や completions が :id として吸われる
    get "entries/categories", to: "entries#categories"
    get "entries/completions", to: "entries#completions"
    get "votes/categories", to: "votes#categories"
    get "votes/completions", to: "votes#completions"
    get "talk_votes/completions", to: "talk_votes#completions"

    resources :entries, only: [ :index, :show, :new, :create ]
    resources :votes, only: [ :create, :destroy ]
    resources :talks, only: [ :index, :show ]
    resources :talk_votes, only: [ :create, :destroy ]
    resources :results, only: [ :index ]
  end

  # 終了済みの回の旧URLもアーカイブへ渡す。それ以外の未定義パスは404。
  get "/events/:event_slug/*path", to: "events#unknown_path"

  namespace :admin do
    resources :administrators, only: [ :index, :destroy ]
    resources :events, only: [ :index, :new, :create, :show, :edit, :update ] do
      resources :talks, only: [ :new, :create, :edit, :update ]
      resources :talk_imports, only: [ :create ]
    end
  end

  # GitHub を設定していない手元の環境でのユーザー切り替え。本番に出ないよう development と test でだけ有効にする
  if Rails.env.local?
    namespace :dev do
      resources :sessions, only: [ :create ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  # 元ファイルには撮影場所（GPS）などが残っているため配らない。画面にはメタデータを消した縮小版（representations）だけを出す。
  # 縮小版の URL に元ファイルの署名付き ID が含まれ、そこから元ファイルの URL を組み立てられてしまうので、ここで塞ぐ。
  # アプリのルートは Active Storage のルートより先に評価されるため、こちらが優先される
  get "/rails/active_storage/blobs/*path", to: ->(_env) { [ 404, { "content-type" => "text/plain" }, [ "Not Found" ] ] }
end
