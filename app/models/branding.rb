class Branding < ApplicationRecord
  belongs_to :tenant

  has_one_attached :logo
  has_one_attached :favicon

  validates :primary_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validates :secondary_color, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true
  validates :font_family, inclusion: { in: %w[Inter Roboto Poppins Montserrat Open\ Sans] }
  validates :custom_domain, format: { with: /\A[a-z0-9.-]+\.[a-z]{2,}\z/ }, allow_blank: true

  def css_variables
    {
      '--primary-color' => primary_color,
      '--secondary-color' => secondary_color || primary_color,
      '--font-family' => font_family
    }
  end

  def logo_url
    logo.attached? ? Rails.application.routes.url_helpers.rails_blob_url(logo) : nil
  end
end
