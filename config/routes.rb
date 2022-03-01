Rails.application.routes.draw do
  # Sidekiq Web UI, only for admins.
  require 'sidekiq/web'
  # authenticate :user, ->(user) { user.admin? } do
  mount Sidekiq::Web => '/sidekiq'
  # end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :users, only: %i[index show create update] do
        member do
          post :github_auth
          patch :destroy_all_records
        end
      end

      get '/me', to: 'users#me'
      resources :repositories, only: %i[index create update show]
      resources :folders, only: %i[show]
      resources :repo_files, only: %i[show]
      resources :code_units, only: %i[show]
      resources :code_unit_docs, only: %i[update]

      get '/search', to: 'search#index'

      # Get branches for onboarding flow
      post '/branches', to: 'repositories#branches'

      # user login
      resources :tokens, only: %i[create]

      # collaborators
      resources :invitations, only: %i[index create]
      post 'users/invite', to: 'users#invite'

      # github webhooks
      post '/github/webhook', to: 'repositories#github_webhook'
      post '/stripe/create-checkout-session', to: 'payments#stripe_subscribe'
      post '/stripe/webhook', to: 'payments#stripe_webhook'
    end
  end
end
