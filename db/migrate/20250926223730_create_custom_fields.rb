class CreateCustomFields < ActiveRecord::Migration[7.2]
  def change
    create_table :custom_fields do |t|
      t.string :name
      t.string :field_type
      t.string :value
      t.timestamps
    end
    add_reference :custom_fields, :client, foreign_key: true
    add_reference :custom_fields, :building, foreign_key: true
  end
end
