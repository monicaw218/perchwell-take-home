class Building < ApplicationRecord
  belongs_to :client, optional: true
  has_many :custom_fields, dependent: :destroy
end
