class CreateEnumDefinition < ActiveRecord::Migration[7.2]
  def change
    create_table :enum_definitions do |t|
      t.integer :enum_value_id, null: false
      t.string :name, null: false
      t.string :value, null: false
      t.timestamps
    end
  add_reference :enum_definitions, :client, foreign_key: true
  end
end
