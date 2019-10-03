Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id
      String :email, null: false
      String :full_name, null: false
      String :github_login, unique: true, null: false
    end
  end
end
