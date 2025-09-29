# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

Client.all.each(&:destroy)

[ "Dream Builders", "Eco-craft", "Master Builders", "Elite Construct", "Innovate Build" ].each do |name|
  Client.find_or_create_by!(name: name)
end

Building.find_or_create_by!(address: '351 Hudson Street', city: 'New York', state: 'NY', zip: '11215', client: Client.first)
Building.find_or_create_by!(address: '352 Hudson Street', city: 'New York', state: 'NY', zip: '11215', client: Client.second)
Building.find_or_create_by!(address: '353 Hudson Street', city: 'New York', state: 'NY', zip: '11215', client: Client.third)
Building.find_or_create_by!(address: '354 Hudson Street', city: 'New York', state: 'NY', zip: '11215', client: Client.fourth)
Building.find_or_create_by!(address: '355 Hudson Street', city: 'New York', state: 'NY', zip: '11215', client: Client.fifth)

EnumDefinition.find_or_create_by!(client: Client.first, enum_value_id: 1, name: "Type of walkway", value: "Brick")
EnumDefinition.find_or_create_by!(client: Client.first, enum_value_id: 2, name: "Type of walkway", value: "Concrete")
EnumDefinition.find_or_create_by!(client: Client.first, enum_value_id: 3, name: "Type of walkway", value: "None")

CustomField.find_or_create_by!(client: Client.first, building: Building.first, name: "Number of bathrooms", field_type: :number, value: 2.5)
CustomField.find_or_create_by!(client: Client.first, building: Building.first, name: "Type of walkway", field_type: :enum_field, value: 1) # Brick
CustomField.find_or_create_by!(client: Client.second, building: Building.second, name: "Living room color", field_type: :freeform, value: "Blue")
CustomField.find_or_create_by!(client: Client.second, building: Building.second, name: "Living room color", field_type: :freeform, value: "Green")
CustomField.find_or_create_by!(client: Client.third, building: Building.third, name: "Number of bathrooms", field_type: :number, value: 1)
CustomField.find_or_create_by!(client: Client.third, building: Building.third, name: "Number of bathrooms", field_type: :number, value: 1.5)
CustomField.find_or_create_by!(client: Client.second, building: Building.second, name: "Dining room color", field_type: :freeform, value: "Gray")
CustomField.find_or_create_by!(client: Client.fourth, building: Building.fourth, name: "Number of bathrooms", field_type: :number, value: 3)
CustomField.find_or_create_by!(client: Client.fifth, building: Building.fifth, name: "Number of bathrooms", field_type: :number, value: 5)
CustomField.find_or_create_by!(client: Client.fifth, building: Building.fifth, name: "Number of bedrooms", field_type: :number, value: 5)
