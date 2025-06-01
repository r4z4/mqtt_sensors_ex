# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     MqttSensors.Repo.insert!(%MqttSensors.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
password = System.fetch_env!("USER_PASSWORD")
current_time = NaiveDateTime.local_now()
alias MqttSensors.Repo
alias MqttSensors.Accounts.User

Repo.insert_all(User, [
  %{
    username: "admin",
    email: "admin@admin.com",
    role: :admin,
    hashed_password: Bcrypt.hash_pwd_salt(password),
    confirmed_at: current_time
  },
  %{
    username: "jimbo",
    email: "jimbo@jimbo.com",
    role: :subadmin,
    hashed_password: Bcrypt.hash_pwd_salt(password),
    confirmed_at: current_time
  },
  %{
    username: "aaron",
    email: "aaron@aaron.com",
    role: :subadmin,
    hashed_password: Bcrypt.hash_pwd_salt(password),
    confirmed_at: current_time
  }
])
