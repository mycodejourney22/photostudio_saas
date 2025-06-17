class ExpenseAttachment < ApplicationRecord
  belongs_to :expense

  has_one_attached :file

  validates :attachment_type, inclusion: {
    in: %w[receipt invoice contract quote purchase_order other]
  }
  validates :filename, presence: true

  scope :receipts, -> { where(attachment_type: 'receipt') }
  scope :invoices, -> { where(attachment_type: 'invoice') }

  def display_type
    attachment_type.humanize
  end

  def file_size_mb
    return 0 unless file_size
    (file_size.to_f / 1.megabyte).round(2)
  end
end
