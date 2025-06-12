# config/routes.rb - Simplified for now
Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#check'

  # Root route - tenant registration for now
  root 'tenant_registration#new'

  # Tenant registration
  get 'signup', to: 'tenant_registration#new', as: :new_tenant_registration
  post 'signup', to: 'tenant_registration#create', as: :tenant_registration
  get 'signup/verify/:token', to: 'tenant_registration#verify', as: :tenant_registration_verify
  get 'signup/success', to: 'tenant_registration#success', as: :tenant_registration_success
  get 'check-subdomain', to: 'tenant_registration#check_subdomain'

  # Authentication routes
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  # API routes
  namespace :api do
    namespace :v1 do
      resources :appointments
      resources :customers
    end
  end

  # Admin routes (super admin)
  namespace :admin do
    root 'dashboard#index'
    resources :tenants do
      member do
        patch :suspend
        patch :activate
      end
    end
  end

  # Tenant-specific routes (simple routing for now)
  # These will work when accessed via subdomain after tenant verification
  get 'dashboard', to: 'dashboard#index'

  # Staff dashboard
  namespace :staff do
    root 'dashboard#index'
  end

  # Core resources
  resources :appointments do
    member do
      patch :confirm
      patch :cancel
      patch :complete
    end
  end

  resources :customers
  resources :studios
end
