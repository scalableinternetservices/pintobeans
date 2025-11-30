Rails.application.routes.draw do

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  #post '/auth/register', to: 'users#register'

  get 'expert/queue', to: 'experts#queue'
  post 'expert/conversations/:conversation_id/claim', to: 'experts#claim'
  post 'expert/conversations/:conversation_id/unclaim', to: 'experts#unclaim'
  get 'expert/profile', to: 'experts#show'
  put 'expert/profile', to: 'experts#update'
  get 'expert/assignments/history', to: 'experts#history'

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get '/health', to: 'health#show'

  # Conversations
  resources :conversations, only: [:index, :show, :create] do
    resources :messages, only: [:index], controller: "messages"
    post 'auto_assign', to: 'expert_assignments#auto_assign'
  end

  # Messages
  resources :messages, only: [:create]
  put "messages/:id/read", to: "messages#mark_read", as: :mark_message_read

  # Update/polling endpoints
  namespace :api do
    get "conversations/updates", to: "updates#conversations"
    get "messages/updates", to: "updates#messages"
    get "expert-queue/updates", to: "updates#expert_queue"
  end

  # Authentication endpoints
  post "/auth/register", to: "authentication#register"
  post "/auth/login",    to: "authentication#login"
  post "/auth/logout",   to: "authentication#logout"
  post "/auth/refresh",  to: "authentication#refresh"
  get  "/auth/me",       to: "authentication#me"

  # Defines the root path route ("/")
  root to: "health#show"
end