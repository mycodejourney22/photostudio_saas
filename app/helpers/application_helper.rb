# app/helpers/application_helper.rb
module ApplicationHelper
  def nav_link_to(path, text, icon_path)
    active = current_page?(path)

    link_to path, class: nav_link_classes(active) do
      content_tag(:div, class: "flex items-center px-4 py-3 rounded-lg transition-colors") do
        svg_icon(icon_path, "w-5 h-5 mr-3") +
        content_tag(:span, text, class: "font-medium")
      end
    end
  end

  def nav_link_classes(active)
    base_classes = "block text-white"
    active_classes = "bg-white bg-opacity-20"
    hover_classes = "hover:bg-white hover:bg-opacity-10"

    "#{base_classes} #{active ? active_classes : hover_classes}"
  end

  def svg_icon(path, classes = "w-5 h-5")
    content_tag(:svg, class: classes, fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
      content_tag(:path, "",
        "stroke-linecap": "round",
        "stroke-linejoin": "round",
        "stroke-width": "2",
        d: path
      )
    end
  end

  def appointment_status_color(status)
    case status.to_s
    when 'confirmed'
      'bg-green-500'
    when 'pending'
      'bg-yellow-500'
    when 'in_progress'
      'bg-blue-500'
    when 'completed'
      'bg-green-600'
    when 'cancelled'
      'bg-red-500'
    else
      'bg-gray-400'
    end
  end

  def plan_color(plan_type)
    case plan_type.to_s
    when 'starter'
      'text-blue-600 bg-blue-100'
    when 'professional'
      'text-purple-600 bg-purple-100'
    when 'enterprise'
      'text-indigo-600 bg-indigo-100'
    else
      'text-gray-600 bg-gray-100'
    end
  end

  def current_user_studios
    current_user.accessible_studio_locations(current_tenant)
  end

  def studio_limited_user?
    !current_user.can_access_all_studios?(current_tenant)
  end

  def user_studio_name
    return "All Locations" if current_user.can_access_all_studios?(current_tenant)
    current_user.assigned_studio_location(current_tenant)&.name || "No Studio Assigned"
  end

  def status_badge(status)
    case status.to_s
    when 'active'
      content_tag(:span, status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full text-green-800 bg-green-100")
    when 'pending'
      content_tag(:span, status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full text-yellow-800 bg-yellow-100")
    when 'suspended'
      content_tag(:span, status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full text-red-800 bg-red-100")
    when 'trial'
      content_tag(:span, status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full text-blue-800 bg-blue-100")
    else
      content_tag(:span, status.humanize, class: "px-2 py-1 text-xs font-medium rounded-full text-gray-800 bg-gray-100")
    end
  end

  # Helper for active navigation states
  def nav_link_active?(path)
    current_page?(path) || (path == dashboard_path && current_page?(root_path))
  end

end
