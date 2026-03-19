class User < ApplicationRecord
  attr_writer :login

  enum :role, { admin: 0, staff: 1 }, default: :staff, validate: true

  has_many :transactions, dependent: :restrict_with_exception

  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  validates :username, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-zA-Z0-9_]+\z/ }
  validates :role, presence: true

  def login
    @login || username || email
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login)&.strip&.downcase

    if login.present?
      where(conditions).find_by("LOWER(username) = :value OR LOWER(email) = :value", value: login)
    else
      find_by(conditions)
    end
  end
end
