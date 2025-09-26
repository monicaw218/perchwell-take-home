class CreateBuildings < ActiveRecord::Migration[7.2]
  def change
    create_table :buildings do |t|
      t.string :address
      t.string :city 
      t.string :state 
      t.string :zip 
      t.string :additional_info 
      t.timestamps
    end

    add_reference :buildings, :client, foreign_key: true
  end
end
