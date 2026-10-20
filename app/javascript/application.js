// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"

// Turbo Drive manages browser history itself - its own pushState calls and
// its own popstate listener - and doesn't recognize entries pushed by the
// live-search/alerts controllers' own history.pushState calls as its own.
// The result: pressing Back after leaving a page Turbo navigated to lands
// on an entry Turbo ignores, while this app's own popstate listeners (which
// are global, not page-scoped) still fire and can swap the wrong page's
// content into whatever happens to be on screen. Disabled outright - this
// app was never relying on Turbo Drive for anything (every link already
// gets a real navigation through the fetch-and-swap controllers below it),
// so there's nothing to lose and one less history system to coordinate.
Turbo.session.drive = false
