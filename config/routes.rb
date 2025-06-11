Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#check'

  # Admin routes (super admin)
  namespace :admin do
    root 'dashboard#index'

    resources :tenants do
      member do
        patch :suspend
        patch :activate
      end
    end

    resources :subscriptions
    resources :analytics, only: [:index]
    resources :support_tickets
  end

  # API routes
  namespace :api do
    namespace :v1 do
      resources :appointments do
        member do
          patch :confirm
          patch :cancel
          patch :complete
        end
      end

      resources :customers do
        resources :photos, only: [:index, :create, :destroy]
      end

      resources :users, only: [:index, :show, :update]
      resources :studios, only: [:index, :show]
      resources :availability, only: [:index]

      # Webhooks
      post '/webhooks/stripe', to: 'webhooks#stripe'
      post '/webhooks/calendar', to: 'webhooks#calendar'
    end
  end

  # Mobile app routes
  namespace :mobile do
    root 'customers#dashboard'

    get 'onboarding', to: 'onboarding#index'
    post 'onboarding', to: 'onboarding#create'

    resources :appointments, only: [:index, :show, :create] do
      member do
        patch :reschedule
        delete :cancel
      end
    end

    resources :photos, only: [:index, :show]
    get 'gallery', to: 'customers#gallery'
    get 'profile', to: 'customers#profile'
    patch 'profile', to: 'customers#update_profile'
  end

  # Authentication routes
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  # Tenant-specific routes
  # constraints(TenantConstraint.new) do
  #   root 'dashboard#index'

  #   # Dashboard
  #   get 'dashboard', to: 'dashboard#index'
  #   get 'dashboard/stats', to: 'dashboard#stats'

  #   # Staff dashboard
  #   namespace :staff do
  #     root 'dashboard#index'
  #     get 'schedule', to: 'dashboard#schedule'
  #     get 'today', to: 'dashboard#today'
  #   end

  #   # Core resources
  #   resources :appointments do
  #     member do
  #       patch :confirm
  #       patch :cancel
  #       patch :complete
  #       patch :reschedule
  #     end

  #     collection do
  #       get :calendar
  #       get :availability
  #     end
  #   end

  #   resources :customers do
  #     resources :photos, except: [:new, :edit]
  #     member do
  #       get :appointments
  #       get :gallery
  #     end
  #   end

  #   resources :studios do
  #     member do
  #       get :schedule
  #       get :availability
  #     end
  #   end

  #   resources :users, except: [:new, :create, :destroy] do
  #     member do
  #       patch :activate
  #       patch :deactivate
  #     end
  #   end

  #   # Photo management
  #   resources :photos, except: [:new, :edit] do
  #     member do
  #       patch :approve
  #       patch :reject
  #       post :share
  #     end

  #     collection do
  #       get :recent
  #       get :pending_approval
  #     end
  #   end

  #   # Reports and analytics
  #   namespace :reports do
  #     get 'revenue', to: 'revenue#index'
  #     get 'bookings', to: 'bookings#index'
  #     get 'customers', to: 'customers#index'
  #     get 'staff_performance', to: 'staff#index'
  #   end

  #   # Settings and configuration
  #   namespace :settings do
  #     root 'general#index'

  #     resource :general, only: [:show, :update]
  #     resource :billing, only: [:show, :update] do
  #       member do
  #         post :change_plan
  #         post :update_payment_method
  #         post :cancel_subscription
  #       end
  #     end

  #     resource :team, only: [:show] do
  #       collection do
  #         post :invite_member
  #         patch :update_member
  #         delete :remove_member
  #       end
  #     end

  #     resources :integrations, only: [:index, :create, :update, :destroy] do
  #       member do
  #         post :connect
  #         delete :disconnect
  #       end
  #     end
  #   end

  #   # Admin-specific routes (tenant admins)
  #   namespace :admin do
  #     root 'dashboard#index'

  #     resource :branding, only: [:show, :edit, :update]

  #     resources :subscription_management, only: [:index, :show] do
  #       collection do
  #         get :usage
  #         get :billing_history
  #       end
  #     end

  #     resources :backup, only: [:index, :create] do
  #       member do
  #         get :download
  #       end
  #     end
  #   end
  # end



  # Main marketing site routes (non-tenant)
  # constraints(MainSiteConstraint.new) do
  #   root 'marketing#index'

  #   get 'features', to: 'marketing#features'
  #   get 'pricing', to: 'marketing#pricing'
  #   get 'about', to: 'marketing#about'
  #   get 'contact', to: 'marketing#contact'
  #   post 'contact', to: 'marketing#create_contact'

  #   # Tenant registration
  #   get 'signup', to: 'tenant_registration#new'
  #   post 'signup', to: 'tenant_registration#create'
  #   get 'signup/verify/:token', to: 'tenant_registration#verify'

  #   # Legal pages
  #   get 'privacy', to: 'legal#privacy'
  #   get 'terms', to: 'legal#terms'
  #   get 'security', to: 'legal#security'
  # end
end
