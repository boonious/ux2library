# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_blacklight-app_session',
  :secret      => 'edb84e73026d3c81c9ea9771090bfb1e4c3ebf5407ea82c596a3c1dab77326b126f187556788bb1b41ea4b86b144da2660947b91076863923765e4be619c557f'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
