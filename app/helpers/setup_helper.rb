module SetupHelper
  def setup_progress_bar(percentage, options = {})
    classes = options[:classes] || "w-full bg-gray-200 rounded-full h-2"
    color = case percentage
            when 0...25 then "bg-red-500"
            when 25...50 then "bg-yellow-500"
            when 50...75 then "bg-blue-500"
            else "bg-green-500"
            end

    content_tag :div, class: classes do
      content_tag :div, "",
        class: "#{color} h-2 rounded-full transition-all duration-300",
        style: "width: #{percentage}%"
    end
  end

  def setup_status_badge(complete, options = {})
    if complete
      content_tag :span, "✓ Complete",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    else
      content_tag :span, "⚠ Incomplete",
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800"
    end
  end

  def role_badge_color(role)
    case role.to_s
    when 'owner' then 'bg-purple-100 text-purple-800'
    when 'manager' then 'bg-blue-100 text-blue-800'
    when 'photographer' then 'bg-green-100 text-green-800'
    when 'editor' then 'bg-yellow-100 text-yellow-800'
    when 'customer_service' then 'bg-pink-100 text-pink-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
end
