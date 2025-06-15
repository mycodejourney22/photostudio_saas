# config/routes.rb
Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by uptime monitors and load balancers.
  get "up" => "rails/health#show", as: :rails_health_check

  # Root route
  root "dashboard#index"

  # Devise routes for authentication
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions',
    passwords: 'users/passwords'
  }

  # Public tenant registration
  get '/register', to: 'tenant_registrations#new', as: :new_tenant_registration
  post '/register', to: 'tenant_registrations#create', as: :tenant_registrations

  # Public booking flow
  scope :book do
    get '/:tenant_slug', to: 'booking#index', as: :public_booking
    get '/:tenant_slug/services', to: 'booking#services', as: :public_booking_services
    get '/:tenant_slug/calendar', to: 'booking#calendar', as: :public_booking_calendar
    get '/:tenant_slug/details', to: 'booking#details', as: :public_booking_details
    post '/:tenant_slug/create', to: 'booking#create', as: :public_booking_create
    get '/:tenant_slug/confirmation/:appointment_id', to: 'booking#confirmation', as: :public_booking_confirmation
  end

  # Tenant-scoped routes (main application)
  scope constraints: TenantConstraint.new do
    # Dashboard
    get '/dashboard', to: 'dashboard#index', as: :dashboard
    get '/dashboard/stats', to: 'dashboard#stats', as: :dashboard_stats

    # Appointments with enhanced sales integration
    resources :appointments do
      member do
        patch :confirm
        patch :cancel
        patch :complete
        patch :assign_photographer
        patch :assign_editor
        patch :mark_shoot_completed
        patch :mark_editing_completed
        post :create_sale
        patch :assign_staff
        patch :update_production
        get :receipt
        get :duplicate
        patch :reschedule
        post 'add_frame', to: 'sales#add_frame'
        post 'add_prints', to: 'sales#add_prints'
        post 'add_photobook', to: 'sales#add_photobook'
      end

      resources :sales, except: [:index], controller: 'appointment_sales'


      collection do
        patch :bulk_update
        get :calendar
        get :export
        get :today
        get :upcoming
        get :past
        post :bulk_confirm
        post :bulk_cancel
        get :walk_in
        post :create_walk_in
      end
    end

    # Sales routes with enhanced appointment integration
    resources :sales do
      member do
        post :add_payment
        patch :add_item
        delete :remove_item
        get :duplicate
        get :receipt
        post :send_receipt
        patch :refund
        get :edit_payment
        patch :update_payment
        get :invoice
        post :send_invoice
        patch :mark_completed
        patch :cancel
      end

      collection do
        get :quick_passport
        post :create_quick_passport
        post :create_from_appointment
        patch :bulk_update
        get :export
        get :daily_summary
        get :weekly_summary
        get :monthly_summary
        post :bulk_mark_paid
        post :bulk_send_receipts
        get :outstanding
        get :recent
        get :new_additional
      end
    end

    # Customers
    resources :customers do
      member do
        patch :activate
        patch :deactivate
        get :appointments
        get :sales
        get :gallery
        post :send_gallery_link
        get :export_data
      end

      collection do
        get :export
        post :import
        patch :bulk_update
        get :inactive
        get :search
      end
    end

    # Staff Members
    resources :staff_members do
      member do
        patch :activate
        patch :deactivate
        get :schedule
        get :performance
        get :assignments
        patch :update_permissions
      end

      collection do
        get :photographers
        get :editors
        get :customer_service
        get :inactive
        patch :bulk_update
      end
    end

    # Service Packages and Tiers
    resources :service_packages do
      resources :service_tiers, except: [:index]

      member do
        patch :activate
        patch :deactivate
        post :duplicate
      end
    end

    # Studios and Locations
    resources :studios do
      resources :studio_locations, except: [:index]

      member do
        patch :activate
        patch :deactivate
        get :schedule
        get :availability
      end
    end

    # Galleries
    resources :galleries do
      member do
        post :add_photos
        delete :remove_photo
        patch :set_cover_photo
        post :share
        get :public_view
        patch :update_settings
      end

      collection do
        get :shared
        post :bulk_create
      end
    end

    # Analytics and Reports
    namespace :analytics do
      get :overview
      get :revenue
      get :bookings
      get :customers
      get :staff_performance
      get :service_popularity
      get :custom_report
    end

    # Settings
    get '/settings', to: 'settings#index', as: :settings
    patch '/settings', to: 'settings#update'

    namespace :settings do
      resource :branding, only: [:show, :edit, :update]
      resource :notifications, only: [:show, :update]
      resource :integrations, only: [:show, :update]
      resource :billing, only: [:show]
      resources :staff_roles, except: [:show]
      resources :service_categories, except: [:show]
    end

    # Branding (legacy route for compatibility)
    resources :brandings, only: [:show, :edit, :update]
  end

  # Nested routes for better organization
  scope :api, defaults: { format: :json } do
    resources :appointments, only: [] do
      member do
        get :sales_summary
        post :quick_sale
        get :availability
        get :customer_info
      end

      collection do
        get :calendar_events
        get :daily_schedule
        get :staff_availability
        get :appointment_sales
      end
    end

    resources :sales, only: [] do
      member do
        get :payment_status
        post :process_payment
        get :items_summary
        get :customer_info
      end

      collection do
        get :daily_stats
        get :weekly_stats
        get :monthly_stats
        get :revenue_forecast
      end
    end

    resources :customers, only: [] do
      member do
        get :appointment_history
        get :purchase_history
        get :preferences
      end

      collection do
        get :search
        get :recent
      end
    end

    # Real-time updates
    get '/live/dashboard_stats', to: 'api/live#dashboard_stats'
    get '/live/appointment_updates', to: 'api/live#appointment_updates'
    get '/live/sales_updates', to: 'api/live#sales_updates'
  end

  # Quick actions routes
  namespace :quick do
    # Sales quick actions
    post 'sales/passport', to: 'sales#passport'
    post 'sales/prints', to: 'sales#prints'
    post 'sales/digital_package', to: 'sales#digital_package'
    post 'sales/custom_product', to: 'sales#custom_product'
    post 'sales/from_appointment/:appointment_id', to: 'sales#from_appointment', as: :sale_from_appointment

    # Appointment quick actions
    post 'appointments/walk_in', to: 'appointments#walk_in'
    post 'appointments/reschedule/:id', to: 'appointments#reschedule', as: :reschedule_appointment
    patch 'appointments/:id/quick_update', to: 'appointments#quick_update', as: :quick_update_appointment

    # Customer quick actions
    post 'customers/create_from_sale', to: 'customers#create_from_sale'
    post 'customers/create_from_appointment', to: 'customers#create_from_appointment'

    post 'sales/add_frame/:appointment_id', to: 'sales#add_frame', as: :add_frame
    post 'sales/add_prints/:appointment_id', to: 'sales#add_prints', as: :add_prints
    post 'sales/add_photobook/:appointment_id', to: 'sales#add_photobook', as: :add_photobook
  end

  # Reports and analytics
  namespace :reports do
    # Sales reports
    get 'sales/daily', to: 'sales#daily'
    get 'sales/weekly', to: 'sales#weekly'
    get 'sales/monthly', to: 'sales#monthly'
    get 'sales/yearly', to: 'sales#yearly'
    get 'sales/by_staff', to: 'sales#by_staff'
    get 'sales/by_service', to: 'sales#by_service'
    get 'sales/by_customer', to: 'sales#by_customer'
    get 'sales/payment_summary', to: 'sales#payment_summary'
    get 'sales/outstanding', to: 'sales#outstanding'

    # Appointment reports
    get 'appointments/daily', to: 'appointments#daily'
    get 'appointments/weekly', to: 'appointments#weekly'
    get 'appointments/monthly', to: 'appointments#monthly'
    get 'appointments/by_photographer', to: 'appointments#by_photographer'
    get 'appointments/by_service', to: 'appointments#by_service'
    get 'appointments/cancellation_rate', to: 'appointments#cancellation_rate'
    get 'appointments/no_show_rate', to: 'appointments#no_show_rate'

    # Revenue reports
    get 'revenue/forecast', to: 'revenue#forecast'
    get 'revenue/trends', to: 'revenue#trends'
    get 'revenue/by_service_type', to: 'revenue#by_service_type'
    get 'revenue/by_location', to: 'revenue#by_location'
    get 'revenue/profit_margins', to: 'revenue#profit_margins'

    # Customer reports
    get 'customers/acquisition', to: 'customers#acquisition'
    get 'customers/retention', to: 'customers#retention'
    get 'customers/lifetime_value', to: 'customers#lifetime_value'
    get 'customers/demographics', to: 'customers#demographics'

    # Staff reports
    get 'staff/performance', to: 'staff#performance'
    get 'staff/schedules', to: 'staff#schedules'
    get 'staff/commissions', to: 'staff#commissions'

    # Export endpoints
    get 'export/sales_csv', to: 'export#sales_csv'
    get 'export/appointments_csv', to: 'export#appointments_csv'
    get 'export/customers_csv', to: 'export#customers_csv'
    get 'export/financial_summary', to: 'export#financial_summary'
  end

  # Webhooks for integrations
  namespace :webhooks do
    post 'stripe/payment_intent', to: 'stripe#payment_intent'
    post 'stripe/invoice_paid', to: 'stripe#invoice_paid'
    post 'calendar/google_sync', to: 'calendar#google_sync'
    post 'email/delivery_status', to: 'email#delivery_status'
  end

  # Admin routes (for super admin functionality)
  namespace :admin do
    resources :tenants do
      member do
        patch :suspend
        patch :activate
        get :usage_stats
        patch :update_plan
      end
    end

    resources :users, only: [:index, :show, :edit, :update, :destroy]
    get :dashboard, to: 'dashboard#index'
    get :system_stats, to: 'dashboard#system_stats'
    get :billing_overview, to: 'billing#overview'
  end

  # Public API (for mobile apps or integrations)
  namespace :public_api, path: 'api/v1' do
    # Authentication
    post 'auth/login', to: 'auth#login'
    post 'auth/refresh', to: 'auth#refresh'
    delete 'auth/logout', to: 'auth#logout'

    # Public booking endpoints
    get 'tenants/:slug/services', to: 'public_booking#services'
    get 'tenants/:slug/availability', to: 'public_booking#availability'
    post 'tenants/:slug/appointments', to: 'public_booking#create_appointment'
    get 'tenants/:slug/appointments/:id', to: 'public_booking#show_appointment'
    patch 'tenants/:slug/appointments/:id', to: 'public_booking#update_appointment'
    delete 'tenants/:slug/appointments/:id', to: 'public_booking#cancel_appointment'

    # Customer portal
    get 'customers/profile', to: 'customers#show_profile'
    patch 'customers/profile', to: 'customers#update_profile'
    get 'customers/appointments', to: 'customers#appointments'
    get 'customers/galleries', to: 'customers#galleries'
    get 'customers/invoices', to: 'customers#invoices'
  end

  # Error pages
  match '/404', to: 'errors#not_found', via: :all
  match '/500', to: 'errors#internal_server_error', via: :all
  match '/422', to: 'errors#unprocessable_entity', via: :all

  # Health checks and monitoring
  get '/health', to: 'health#index'
  get '/health/database', to: 'health#database'
  get '/health/redis', to: 'health#redis'
  get '/health/storage', to: 'health#storage'

  # Catch-all route for tenant subdomains (should be last)
  # This handles custom domain routing if you implement it
  get '*path', to: 'application#handle_routing_error', constraints: lambda { |req|
    req.host != Rails.application.config.default_host
  }
end
