# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "react" # @19.3.1
pin "react-dom/client", to: "react-dom--client.js" # @19.3.1
pin "react-dom" # @19.3.1
pin "scheduler" # @0.28.0
pin "react/jsx-runtime", to: "react--jsx-runtime.js" # @19.3.1
