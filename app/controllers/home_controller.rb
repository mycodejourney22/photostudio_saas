class HomeController < ApplicationController
    skip_before_action :set_current_tenant
    skip_around_action :with_tenant_scope
    skip_before_action :authenticate_user!

    layout 'public'

    def index
        if user_signed_in?
            redirect_to dashboard_path
        end
    end
end
