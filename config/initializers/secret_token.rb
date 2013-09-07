# Be sure to restart your server when you modify this file.

# Your secret key for verifying the integrity of signed cookies.
# If you change this key, all old signed cookies will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.


# you can make a new token with
#
# SecureRandom.hex(64)
#

Dojo4::Application.config.secret_token = App.secret_token
