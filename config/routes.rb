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

    # Dashboard routes
    get '/', to: 'dashboard#index'
    get 'dashboard', to: 'dashboard#index'

    # Staff dashboard
    get 'staff', to: 'staff/dashboard#index'

    # Tenant Admin routes
    get 'admin', to: 'admin/branding#show'
    get 'admin/branding', to: 'admin/branding#show'
    patch 'admin/branding', to: 'admin/branding#update'
    put 'admin/branding', to: 'admin/branding#update'

    # Core resource routes
    resources :customers
    resources :studios

    # Staff Members routes
    resources :staff_members do
      member do
        patch :toggle_active
      end
    end

    # Enhanced Appointments routes
    resources :appointments do
      member do
        patch :confirm             # For confirming appointments
        patch :cancel              # For cancelling appointments
        patch :complete            # For completing appointments
        post :assign_staff         # AJAX endpoint for staff assignment
        post :update_production    # AJAX endpoint for production updates
        post :create_sale         # Create sale from appointment
      end

      collection do
        patch :bulk_update        # For bulk actions like confirm_all_pending
      end
    end

    # Sales management routes
    resources :sales do
      member do
        post :add_payment          # AJAX endpoint for adding payments
        post :add_item            # AJAX endpoint for adding items
        delete :remove_item       # AJAX endpoint for removing items
      end

      collection do
        post :passport_photos     # Quick passport photo sale
      end
    end

    # Sale Items routes (nested under sales)
    resources :sales do
      resources :sale_items, only: [:create, :update, :destroy]
    end

    # Public booking flow
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

    # API routes for AJAX calls
    namespace :api do
      namespace :v1 do
        # Appointment API endpoints
        resources :appointments, only: [] do
          member do
            patch :assign_photographer
            patch :assign_editor
            patch :mark_shoot_completed
            patch :mark_editing_completed
            patch :update_delivery_date
            post :add_production_note
          end
        end

        # Sales API endpoints
        resources :sales, only: [] do
          member do
            post :add_payment
            post :process_payment
          end
        end

        # Sale Items API endpoints
        resources :sale_items, only: [:create, :destroy]

        # Staff Members API endpoints
        resources :staff_members, only: [:index] do
          collection do
            get :photographers
            get :editors
            get :customer_service
          end
        end

        # General API endpoints
        resources :customers, only: [:index, :show]
        resources :studios, only: [:index, :show]
      end
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
