require "json"
require "date"

data = JSON.parse(File.read("data.json"))
result = { "rentals" => [] }
data["rentals"].each { |rental|
    car = data["cars"].detect { |car| car["id"] == rental["car_id"] }
    duration = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1
    price = rental["distance"] * car["price_per_km"]
    price_per_day = car["price_per_day"]

    if duration > 10 then
        price += 0.5 * price_per_day * (duration - 10)
        duration = 10
    end

    if duration > 4 then
        price += 0.7 * price_per_day * (duration - 4)
        duration = 4
    end

    if duration > 1 then
        price += 0.9 * price_per_day * (duration - 1)
        duration = 1
    end

    price += duration * price_per_day
    price = price.to_i

    result["rentals"] += [{
        "id" => rental["id"],
        "price" => price
    }]
}
File.write("output.json", JSON.pretty_generate(result) + "\n")
