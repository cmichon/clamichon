Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :github_login, unique: true, null: false
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
      String :corspoc_name
      String :corspoc_email
      String :corspoc_phone
      String :corspoc_fax
    end
  end
end
