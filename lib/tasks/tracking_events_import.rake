namespace :tracking_events do
    desc "Import tracking events from tracking_events.csv located in the app root"
    task import: :environment do
      path = Rails.root.join("tracking_events.csv")
  
      unless File.exist?(path)
        puts "ERROR: File not found:"
        puts "  #{path}"
        puts ""
        puts "Place tracking_events.csv in the top-level directory of the Rails app."
        exit 1
      end
  
      puts "Importing tracking events from #{path}..."
      
      TrackingEvents::CsvImporter.new(path).call
  
      puts "Done."
    end
  end