admin = User.find_or_initialize_by(email: "admin@fuelloyalty.test")
admin.name = "Admin"
admin.username = "admin"
admin.phone_number = "9000000001"
admin.password = "password123"
admin.password_confirmation = "password123"
admin.role = :admin
admin.save!

staff = User.find_or_initialize_by(email: "staff@fuelloyalty.test")
staff.name = "Staff"
staff.username = "staff"
staff.phone_number = "9000000002"
staff.password = "password123"
staff.password_confirmation = "password123"
staff.role = :staff
staff.save!
