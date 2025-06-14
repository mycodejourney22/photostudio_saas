# config/routes.rb
Rails.application.routes.draw do
  # Health check
  get '/health', to: 'health#check'

  # Main site routes (no subdomain or www subdomain)
  constraints MainSiteConstraint.new do
    root 'tenant_registration#new'

    # Tenant registration routes
    get 'signup', to: 'tenant_registration#new', as: :new_tenant_registration
    post 'signup', to: 'tenant_registration#create', as: :tenant_registration
    get 'signup/verify/:token', to: 'tenant_registration#verify', as: :tenant_registration_verify
    get 'signup/verified', to: 'tenant_registration#verified', as: :tenant_registration_verified
    get 'signup/success', to: 'tenant_registration#success', as: :tenant_registration_success
    get 'check-subdomain', to: 'tenant_registration#check_subdomain'
  end

  # Tenant-specific routes (subdomain required)
  constraints TenantConstraint.new do
    # Authentication routes for tenants
    devise_for :users, controllers: {
      registrations: 'users/registrations',
      sessions: 'users/sessions',
      passwords: 'users/passwords'
    }

    # Dashboard
    get '/', to: 'dashboard#index'
    get 'dashboard', to: 'dashboard#index'

    # Staff dashboard
    get 'staff', to: 'staff/dashboard#index'

    # Tenant Admin
    get 'admin', to: 'admin/branding#show'
    get 'admin/branding', to: 'admin/branding#show'
    patch 'admin/branding', to: 'admin/branding#update'
    put 'admin/branding', to: 'admin/branding#update'

    resources :appointments do
      member do
        patch :confirm
        patch :cancel
        patch :complete
      end
      collection do
        patch :bulk_update
      end
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

    # API routes
    namespace :api do
      namespace :v1 do
        resources :appointments
        resources :customers
        resources :studios
      end
    end

      scope '/book', as: 'booking' do
    get '/', to: 'booking#index', as: ''

    # Step 1: Studio Location Selection
    get '/location/:studio_location_id', to: 'booking#packages', as: '_packages'

    # Step 2: Service Package Selection
    get '/location/:studio_location_id/packages', to: 'booking#packages', as: '_packages_alt'

    # Step 3: Service Tier Selection
    get '/location/:studio_location_id/service/:service_package_id', to: 'booking#tiers', as: '_tiers'

    # Step 4: Time Slot Selection
    get '/location/:studio_location_id/service/:service_package_id/tier/:service_tier_id/slots',
        to: 'booking#slots', as: '_slots'

    # Step 5: Customer Details & Payment
    get '/location/:studio_location_id/service/:service_package_id/tier/:service_tier_id/details',
        to: 'booking#details', as: '_details'

    # Step 6: Create Appointment
    post '/location/:studio_location_id/service/:service_package_id/tier/:service_tier_id/create',
         to: 'booking#create', as: '_create'

    # Payment callback
    get '/payment/callback', to: 'booking#payment_callback', as: '_payment_callback'

    # Confirmation page
    get '/confirmation/:appointment_id', to: 'booking#confirmation', as: '_confirmation'
  end
  end

  # Super Admin routes (admin subdomain only)
  constraints subdomain: 'admin' do
    get '/', to: 'admin/tenants#index'

    resources :tenants, controller: 'admin/tenants' do
      member do
        patch :suspend
        patch :activate
      end
    end
  end
end
