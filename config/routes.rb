Rails.application.routes.draw do
  root "home#index"

  get "/login", to: "sessions#new"
  delete "/logout", to: "sessions#destroy"

  get "/terms", to: "pages#terms"
  get "/privacy", to: "pages#privacy"

  resources :events, only: [ :show ] do
    # resources より先に宣言しないと、categories や completions が :id として吸われる
    get "entries/categories", to: "entries#categories"
    get "entries/completions", to: "entries#completions"
    get "votes/categories", to: "votes#categories"
    get "votes/completions", to: "votes#completions"
    get "talk_votes/completions", to: "talk_votes#completions"

    resources :entries, only: [ :index, :show, :new, :create ]
    resources :votes, only: [ :create ]
    resources :talks, only: [ :index, :show ]
    resources :talk_votes, only: [ :create ]
  end

  namespace :admin do
    resources :events, only: [ :index, :new, :create, :show, :update ]
  end

  # GitHub OAuth を入れるまでの代用。本番に出ないよう development と test でだけ有効にする
  if Rails.env.local?
    namespace :dev do
      resources :sessions, only: [ :create ]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
