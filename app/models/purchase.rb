class Purchase < ApplicationRecord
  validates :item, :price, :purchase_date, presence: true
  belongs_to :user
  belongs_to :item
end
