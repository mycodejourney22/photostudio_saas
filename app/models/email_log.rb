class EmailLog < ApplicationRecord
  belongs_to :tenant
  belongs_to :appointment

  # validates :email_type, presence: true, inclusion: {
  #   in: %w[confirmation reminder feedback_request status_update]
  # }
  validates :recipient_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  scope :sent, -> { where.not(sent_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }
  scope :by_type, ->(type) { where(email_type: type) }
  scope :recent, -> { where(created_at: 1.week.ago..Time.current) }

  def sent?
    sent_at.present?
  end

  def failed?
    failed_at.present?
  end

  def self.stats_for_tenant(tenant, period = 1.month.ago..Time.current)
    where(tenant: tenant, created_at: period).group(:email_type).count
  end
end
