class CustomField < ApplicationRecord
  belongs_to :client, optional: true
  belongs_to :building, optional: true

  enum field_type: { number: "number", freeform: "freeform", enum_field: "enum" }
end
