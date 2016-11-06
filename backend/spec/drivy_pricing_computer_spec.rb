require 'level6/main'

describe DrivyPricingComputer do
    OUTPUT_FILE = "spec/output.json"

    after(:all) do
        File.delete(OUTPUT_FILE)
    end

    context "given a simple data file" do
        before(:all) do
            @drivy = DrivyPricingComputer.new(
                :input_file => "spec/simple.json",
                :export_original_rentals => true,
                :export_price => true,
                :export_commission => true
            )
        end

        it "exports the operations properly" do
            @drivy.export_operations(:output_file => OUTPUT_FILE)
        end

        it "computes the right price" do
            output = JSON.parse(File.read(OUTPUT_FILE))
            expect(output.dig("rentals", 0, "price")).to eql(3000)
        end

        it "splits the commission properly" do
            output = JSON.parse(File.read(OUTPUT_FILE))
            expect(output.dig("rentals", 0, "commission", "insurance_fee")).to eql(450)
            expect(output.dig("rentals", 0, "commission", "assistance_fee")).to eql(100)
            expect(output.dig("rentals", 0, "commission", "drivy_fee")).to eql(350)
        end
    end

    context "given a data file with modifications" do
        before(:all) do
            @drivy = DrivyPricingComputer.new(
                :input_file => "spec/modifications.json",
                :export_original_rentals => true,
                :export_commission => false
            )
        end

        it "exports the operations properly" do
            @drivy.export_operations(:output_file => OUTPUT_FILE)
        end

        it "does not export the price or the commission" do
            output = JSON.parse(File.read(OUTPUT_FILE))
            expect(output.dig("rentals", 0, "price")).to be_nil
            expect(output.dig("rentals", 0, "commission")).to be_nil
        end

        it "updates the balance for each actor" do
            output = JSON.parse(File.read(OUTPUT_FILE))
            expect(output.dig("rentals", 0, "actions").length).to eql(5)
            expect(output.dig("rental_modifications", 0, "actions").length).to eql(5)

            expect(output.dig("rentals", 0, "actions", 0, "who")).to eql("driver")
            expect(output.dig("rentals", 0, "actions", 0, "type")).to eql("debit")
            expect(output.dig("rentals", 0, "actions", 0, "amount")).to eql(3500)

            expect(output.dig("rental_modifications", 0, "actions", 0, "who")).to eql("driver")
            expect(output.dig("rental_modifications", 0, "actions", 0, "type")).to eql("debit")
            expect(output.dig("rental_modifications", 0, "actions", 0, "amount")).to eql(19010)

            expect(output.dig("rentals", 0, "actions", 1, "who")).to eql("owner")
            expect(output.dig("rentals", 0, "actions", 1, "type")).to eql("credit")
            expect(output.dig("rentals", 0, "actions", 1, "amount")).to eql(2170)

            expect(output.dig("rental_modifications", 0, "actions", 1, "who")).to eql("owner")
            expect(output.dig("rental_modifications", 0, "actions", 1, "type")).to eql("credit")
            expect(output.dig("rental_modifications", 0, "actions", 1, "amount")).to eql(10227)
        end
    end
end
