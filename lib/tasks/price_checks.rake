require "csv"

namespace :price_checks do
  desc "Generate a sample price_checks.csv in the app root (mirrors tracking_events.csv's format)"
  task generate_sample: :environment do
    srand(42) # reproducible output - anyone regenerating the sample file gets the same rows
    path = Rails.root.join("price_checks.csv")
    pairs = ActiveRecord::Base.connection.select_rows(<<~SQL)
      SELECT DISTINCT s.address, p.name
      FROM tracking_events te
      JOIN stores s ON s.id = te.store_id
      JOIN products p ON p.id = te.product_id
      ORDER BY s.address, p.name
    SQL

    date_range = (Date.new(2024, 12, 5)..Date.new(2025, 12, 5))

    CSV.open(path, "w") do |csv|
      csv << ["Address", "Product Name", "Date", "Price Cents"]
      pairs.each do |address, product_name|
        rand(1..3).times do
          csv << [address, product_name, rand(date_range).iso8601, rand(100..9_999)]
        end
      end
    end

    puts "Wrote #{path} (#{pairs.size} product/store pairs, ~#{pairs.size * 2} rows)"
  end

  desc "Import price checks from price_checks.csv located in the app root"
  task import: :environment do
    path = Rails.root.join("price_checks.csv")

    unless File.exist?(path)
      puts "ERROR: File not found:"
      puts "  #{path}"
      puts ""
      puts "Run `bin/rails price_checks:generate_sample` first, or place your own price_checks.csv in the app root."
      exit 1
    end

    puts "Importing price checks from #{path}..."
    PriceChecks::CsvImporter.new(path).call
    puts "Done."
  end
end
