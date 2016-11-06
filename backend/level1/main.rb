require "json"
require "date"

data = JSON.parse(File.read("data.json"))
result = { "rentals" => [] }
data["rentals"].each { |rental|
    car = data["cars"].detect { |car| car["id"] == rental["car_id"] }
    duration = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1
    price = rental["distance"] * car["price_per_km"] + duration * car["price_per_day"]

    result["rentals"] += [{
        "id" => rental["id"],
        "price" => price
    }]
}
File.write("output.json", JSON.pretty_generate(result) + "\n")
