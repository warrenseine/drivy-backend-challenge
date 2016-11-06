require "json"
require "date"

data = JSON.parse(File.read("data.json"))
result = { "rentals" => [] }
data["rentals"].each { |rental|
    car = data["cars"].detect { |car| car["id"] == rental["car_id"] }
    duration = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1
    price = rental["distance"] * car["price_per_km"]
    price_per_day = car["price_per_day"]

    billed_days = duration

    if billed_days > 10 then
        price += 0.5 * price_per_day * (billed_days - 10)
        billed_days = 10
    end

    if billed_days > 4 then
        price += 0.7 * price_per_day * (billed_days - 4)
        billed_days = 4
    end

    if billed_days > 1 then
        price += 0.9 * price_per_day * (billed_days - 1)
        billed_days = 1
    end

    price += billed_days * price_per_day
    price = price.to_i

    commission = (price * 0.3).to_i
    insurance_fee = commission / 2
    assistance_fee = duration * 100
    drivy_fee = commission - insurance_fee - assistance_fee

    deductible_reduction = if rental["deductible_reduction"] then duration * 4 * 100 else 0 end

    result["rentals"] += [{
        "id" => rental["id"],
        "price" => price,
        "options" => {
            "deductible_reduction" => deductible_reduction
        },
        "commission" => {
            "insurance_fee" => insurance_fee,
            "assistance_fee" => assistance_fee,
            "drivy_fee" => drivy_fee
        }
    }]
}

File.write("output.json", JSON.pretty_generate(result) + "\n")
