module Admin
  class AuthController < ::AuthController
    layout 'admin'

    nav_for:auth do |nav|
    end

    nav_for:main do |nav|
    end
  end
end
