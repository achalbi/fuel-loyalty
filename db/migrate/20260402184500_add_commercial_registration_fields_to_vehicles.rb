class AddCommercialRegistrationFieldsToVehicles < ActiveRecord::Migration[8.0]
  def change
    change_table :vehicles, bulk: true do |t|
      t.string :commercial_company_name
      t.string :commercial_contact_name
      t.string :commercial_contact_phone_number
      t.text :commercial_address
      t.text :commercial_notes
    end
  end
end
