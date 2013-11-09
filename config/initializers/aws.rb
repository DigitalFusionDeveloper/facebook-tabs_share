if App.sekrets.has_key?(:aws)

  AWS.config(App.sekrets[:aws] || {})

end
