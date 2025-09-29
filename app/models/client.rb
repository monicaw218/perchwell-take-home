class Client < ApplicationRecord
  has_many :buildings, dependent: :destroy
  has_many :custom_fields, dependent: :destroy
  has_many :enum_definitions, dependent: :destroy
end
