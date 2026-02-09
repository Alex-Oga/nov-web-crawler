class AddSessionTokensAndExpiration < ActiveRecord::Migration[8.0]
  def change
    # Add columns as nullable first
    add_column :sessions, :session_token, :string, null: true
    add_column :sessions, :expires_at, :datetime, null: true
    
    # Populate existing sessions with tokens and expiration dates
    reversible do |dir|
      dir.up do
        Session.reset_column_information
        Session.find_each do |session|
          session.update!(
            session_token: SecureRandom.urlsafe_base64(32),
            expires_at: 30.days.from_now
          )
        end
        
        # Now make the columns non-nullable
        change_column_null :sessions, :session_token, false
        change_column_null :sessions, :expires_at, false
      end
    end
    
    # Add indexes
    add_index :sessions, :session_token, unique: true
    add_index :sessions, :expires_at
    add_index :sessions, [:user_id, :expires_at]
  end
end