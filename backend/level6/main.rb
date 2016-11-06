require "json"
require "date"

class DrivyPricingComputer
    DATA_SCHEMA = {
        :cars => Array,
        :rentals => Array,
        :rental_modifications => Array
    }

    CAR_SCHEMA = {
        :id => Integer,
        :price_per_day => Integer,
        :price_per_km => Integer
    }

    RENTAL_SCHEMA = {
        :car_id => Integer,
        :start_date => String,
        :end_date => String,
        :distance => Integer
    }

    RENTAL_MODIFICATION_SCHEMA = {
        :rental_id => Integer
    }

    def initialize(
        input_file:,
        apply_discount: true,
        export_commission: true,
        export_price: false,
        export_original_rental_actions: true,
        export_original_rentals: false
    )
        @data = JSON.parse(File.read(input_file))

        raise "Invalid data file #{input_file}" if not DATA_SCHEMA.all? { |key, type| @data[key.to_s].is_a? type }

        @apply_discount = apply_discount
        @export_commission = export_commission
        @export_price = export_price
        @export_original_rental_actions = export_original_rental_actions
        @export_original_rentals = export_original_rentals
    end

    def export_operations(output_file:)
        result = {
            "rentals" => [],
            "rental_modifications" => []
        }

        @data["rentals"].each { |rental|
            price, deductible_reduction, insurance_fee, assistance_fee, drivy_fee = compute_pricing(
                :rental => rental
            )

            r = {
                "id" => rental["id"]
            }

            if @export_price then
                r["price"] = price
            end

            if @export_commission then
                r["commission"] = {
                    "insurance_fee" => insurance_fee,
                    "assistance_fee" => assistance_fee,
                    "drivy_fee" => drivy_fee
                }
            end

            if @export_original_rental_actions then
                r["actions"] = [
                    {
                      "who" => "driver",
                      "type" => "debit",
                      "amount" => price + deductible_reduction
                    },
                    {
                      "who" => "owner",
                      "type" => "credit",
                      "amount" => price - insurance_fee - assistance_fee - drivy_fee
                    },
                    {
                      "who" => "insurance",
                      "type" => "credit",
                      "amount" => insurance_fee
                    },
                    {
                      "who" => "assistance",
                      "type" => "credit",
                      "amount" => assistance_fee
                    },
                    {
                      "who" => "drivy",
                      "type" => "credit",
                      "amount" => drivy_fee + deductible_reduction
                    }
                ]
            end

            result["rentals"] += [r]
        }

        @data["rental_modifications"].each { |rental_modification|
            raise "Invalid rental modification item #{rental_modification['id']}" if not RENTAL_MODIFICATION_SCHEMA.all? { |key, type| rental_modification[key.to_s].is_a? type }

            rental = @data["rentals"].detect { |rental| rental["id"] == rental_modification["rental_id"] }

            rental["start_date"] = rental_modification["start_date"] if rental_modification["start_date"]
            rental["end_date"] = rental_modification["end_date"] if rental_modification["end_date"]
            rental["distance"] = rental_modification["distance"] if rental_modification["distance"]

            # Recompute the price with updated rental data.
            price, deductible_reduction, insurance_fee, assistance_fee, drivy_fee = compute_pricing(
                :rental => rental
            )

            # Adjust the type/amount of an action based on its new cost.
            adjust_amount = -> (action, new_amount) {
                amount_difference = new_amount - action["amount"]
                next if amount_difference == 0
                type = action["type"]
                if amount_difference < 0 then
                    type = if type == "credit" then "debit" else "credit" end
                end
                {
                    "who" => action["who"],
                    "type" => type,
                    "amount" => amount_difference.abs
                }
            }

            # Create a new action with the amount difference.
            actions = []
            rental = result["rentals"].detect { |rental| rental["id"] == rental_modification["rental_id"] }
            rental["actions"].each { |action|
                case action["who"]
                    when "driver"
                        actions += [adjust_amount.call(action, price + deductible_reduction)]
                    when "owner"
                        actions += [adjust_amount.call(action, price - insurance_fee - assistance_fee - drivy_fee)]
                    when "insurance"
                        actions += [adjust_amount.call(action, insurance_fee)]
                    when "assistance"
                        actions += [adjust_amount.call(action, assistance_fee)]
                    when "drivy"
                        actions += [adjust_amount.call(action, drivy_fee + deductible_reduction)]
                end
            }

            result["rental_modifications"] += [{
                "id" => rental_modification["id"],
                "rental_id" => rental_modification["rental_id"],
                "actions" => actions
            }]

        }

        result.delete("rentals") if not @export_original_rentals

        File.write(output_file, JSON.pretty_generate(result) + "\n")
    end

    def compute_pricing(rental:)
        raise "Invalid rental item" if not RENTAL_SCHEMA.all? { |key, type| rental[key.to_s].is_a? type }

        # Retrieve the car for this rental.
        car = @data["cars"].detect { |car| car["id"] == rental["car_id"] }
        raise "Invalid car id #{rental['car_id']}" if not car
        raise "Invalid car item #{rental['car_id']}" if not CAR_SCHEMA.all? { |key, type| car[key.to_s].is_a? type }

        # Get the duration of the rental (in days).
        duration = (Date.parse(rental["end_date"]) - Date.parse(rental["start_date"])).to_i + 1
        raise "Invalid date range #{rental['start_date']} - #{rental['end_date']}" if duration <= 0

        price = rental["distance"] * car["price_per_km"]
        price_per_day = car["price_per_day"]

        billed_days = duration

        # Apply a discount based on the rental duration.
        if @apply_discount then
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
        end

        # Add the full price for the first day.
        price += billed_days * price_per_day

        price = price.to_i

        # Split commission (see `README.md`).
        commission = (price * 0.3).to_i
        insurance_fee = commission / 2
        assistance_fee = duration * 100
        drivy_fee = commission - insurance_fee - assistance_fee

        deductible_reduction = if rental["deductible_reduction"] then duration * 4 * 100 else 0 end

        # Return all price/fee information.
        [price, deductible_reduction, insurance_fee, assistance_fee, drivy_fee]
    end

    private :compute_pricing
end

if __FILE__ == $0
    drivy = DrivyPricingComputer.new(:input_file => "data.json")
    drivy.export_operations(:output_file => "output.json")
end
