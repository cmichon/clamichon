Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :login, unique: true, null: false
      FalseClass :cla_invidual, null: false, default: false
      FalseClass :cla_corporate, null: false, default: false
      String :full_name, null: false
      String :public_name
      String :postal_address, null: false
      String :country, null: false
      String :email, null: false
      String :phone, null: false
      String :corporation_name
      String :corporation_address
      String :corporation_spoc_name
      String :corporation_spoc_email
      String :corporation_spoc_phone
      String :corporation_spoc_fax
    end
  end
end

# vim:et:ff=unix:sw=2:ts=2:
