require 'rails_helper'

RSpec.describe Trip, type: :model do
  let(:trip) { FactoryGirl.build(:trip) }

  it { is_expected.to have_many(:rides) }
  it { is_expected.to have_many(:comments) }
  it { is_expected.to belong_to(:user) }

  describe "#valid?" do
    it { is_expected.to validate_presence_of(:from) }
    it { is_expected.to validate_presence_of(:to) }
    it { is_expected.to validate_presence_of(:departure) }
    it { is_expected.to validate_presence_of(:arrival) }
    it { is_expected.to validate_presence_of(:travelling_with) }

    describe '#hitchhikes' do
      it 'creates 1 ride on trip if hitchhikes equals 1' do
        trip = FactoryGirl.build(:trip, hitchhikes: 1)
        trip.save
        expect(trip.rides.size).to eq(1)
      end
    end
  end

  describe '#departure and #arrival' do
    it 'should save departure_date and departure_time to departure' do
      trip = FactoryGirl.build(:trip,
                               departure: '5 July, 2013',
                               departure_time: '08:00 AM')

      expect(trip.departure.strftime("%d/%m/%Y %H:%M")).to eq("05/07/2013 08:00")
    end

    it 'should save arrival_date and arrival_time to arrival' do
      trip = FactoryGirl.build(:trip,
                               arrival: '5 July, 2013',
                               arrival_time: '08:00 AM')

      expect(trip.arrival.strftime("%d/%m/%Y %H:%M")).to eq("05/07/2013 08:00")
    end
  end

  describe "factories" do
    it "should generate a valid trip" do
      expect(trip).to be_valid
    end
  end

  describe "#kmh" do
    it "returns km/h" do
      trip.distance   = 50_000 # 50 kms
      trip.departure  = "07/12/2011 10:00"
      trip.arrival    = "07/12/2011 13:00" 
      expect(trip.kmh).to eq(16)
    end
  end

  describe "#to_param" do
    context "has attribute from_city and to_city" do
      it "should output correctly" do
        allow(trip).to receive(:id).and_return(123)
        trip.from_city = 'Cologne'
        trip.to_city = 'Berlin'
        expect(trip.to_param).to eq("#{trip.id}-cologne-to-berlin")
      end
    end

    context "has attribute from and to, but not from_city and to_city" do
      it "should output correctly" do
        allow(trip).to receive(:id).and_return(123)
        trip.from = "Berliner Str./B1/B5, Hoppegarten"
        trip.to   = "Warszawa"
        expect(trip.to_param).to eq("#{trip.id}-berliner-str-2fb1-2fb5-2c-hoppegarten-to-warszawa")
      end
    end
  end

  describe '#gmaps_difference' do
    context "if you are slower than gmaps_difference" do
      it "has a postive gmaps_difference" do
        trip.departure = '07/11/2009 10:00'
        trip.arrival   = '07/11/2009 13:00'
        trip.gmaps_duration = 2.hours.to_i
        expect(trip.gmaps_difference).to eq(3600)
      end
    end

    context "if you are faster than gmaps_difference" do
      it "has a negative gmaps_difference" do
        trip.departure = '07/11/2009 10:00'
        trip.arrival   = '07/11/2009 13:00'
        trip.gmaps_duration = 4.hours.to_i
        expect(trip.gmaps_difference).to eq(-3600)
      end
    end
  end

  describe '#duration' do
    it "should reckon duration with arrival - departure" do
      expect(trip.duration).to eq(trip.arrival - trip.departure)
    end
  end

  describe '#hitchability' do
    context "gmaps_duration is set" do
      it 'reckons hitchability' do
        trip.gmaps_duration = 9.hours.to_f
        trip.departure = '07/11/2009 10:00'
        trip.arrival   = '07/11/2009 20:00'
        expect(trip.hitchability).to eq(1.11)
      end
    end

    context "gmaps_duration is not set" do
      it 'does not reckon hitchability' do
        trip.gmaps_duration = nil
        trip.departure = '07/11/2009 10:00'
        trip.arrival   = '07/11/2009 20:00'
        expect(trip.hitchability).to eq(nil)
      end
    end
  end

  describe "#total_waiting_time" do
    it 'returns the total accumulated waiting_time' do
      trip.rides << FactoryGirl.build(:ride, waiting_time: 5)
      trip.rides << FactoryGirl.build(:ride, waiting_time: 6)
      expect(trip.total_waiting_time).to eq('11 minutes')
    end

    it 'returns nil if no waiting time has been logged' do
      trip.rides << FactoryGirl.build(:ride, waiting_time: nil)
      expect(trip.total_waiting_time).to eq(nil)
    end
  end

  describe "#overall_experience" do
    context "has only good experiences" do
      it "returns a good experience" do
        trip.rides << FactoryGirl.create(:ride, :experience => 'good')
        expect(trip.overall_experience).to eq('good')
      end
    end

    context "has a neutral experience" do
      it "returns a neutral experience" do
        trip.rides << FactoryGirl.build_stubbed( :ride, :experience => 'good' )
        trip.rides << FactoryGirl.build_stubbed( :ride, :experience => 'neutral' )
        expect(trip.overall_experience).to eq('neutral')
      end
    end

    context "has a bad experience" do
      it "returns a bad experience" do
        trip.rides << FactoryGirl.build(:ride, :experience => 'good')
        trip.rides << FactoryGirl.build(:ride, :experience => 'neutral')
        trip.rides << FactoryGirl.build(:ride, :experience => 'bad')
        expect(trip.overall_experience).to eq('bad')
      end
    end

    context "has a bad and a very good experience" do
      it "returns a bad experience" do
        trip.rides << FactoryGirl.build(:ride, :experience => 'very good')
        trip.rides << FactoryGirl.build(:ride, :experience => 'bad')
        expect(trip.overall_experience).to eq('bad')
      end
    end
  end

  describe 'self.data_for_country_map' do
    before do
      trip = FactoryGirl.build(:trip, hitchhikes: 0)
      trip.rides.build(experience: 'very good', vehicle: "car")
      trip.rides.build(experience: 'good', vehicle: "plane")
      trip.rides.build(experience: 'bad', vehicle: "bus")
      trip.country_distances.build(country: 'Germany', country_code: "DE", distance: 3000)
      trip.save!
      trip_2 = FactoryGirl.build(:trip, hitchhikes: 0)
      trip_2.rides.build(experience: 'very bad', vehicle: "boat")
      trip_2.rides.build(experience: 'bad', vehicle: "truck")
      trip_2.country_distances.build(country: 'Spain', country_code: "ES", distance: 3000)
      trip_2.save!
      trip_3 = FactoryGirl.build(:trip, hitchhikes: 0)
      trip_3.rides.build(experience: 'neutral', vehicle: "motorcycle")
      trip_3.country_distances.build(country: 'Poland', country_code: "PL", distance: 3000)
      trip_3.save!
    end

    it 'should return the json for a google chart DataTable' do
      expect(Trip.data_for_country_map).to eq({
        "rides_count" => { "DE" => 3, "PL" => 1, "ES" => 2},
        "very good" => { "DE" => 1 },
        "good" => { "DE" => 1 },
        "good_and_very_good" => { "DE" => 2 },
        "good_xp_ratio" => { "DE" => 0.6666666666666666 },
        "neutral" => { "PL" => 1 },
        "bad" => { "ES" => 1, "DE" => 1 },
        "very bad" => { "ES" => 1 },
        "bad_and_very_bad" => { "DE" => 1, "ES" => 2 }
        #"car"=>{"DE"=>1},
        #"bus"=>{},
        #"truck"=>{"ES"=>1},
        #"motorcycle"=>{"PL"=>1},
        #"plane"=>{"DE"=>1},
        #"boat"=>{"ES"=>1}
      })
    end
  end

  describe 'add_ride' do
    it 'adds a ride to the trip' do
      trip.save
      expect(trip.rides.size).to eq(1)
      trip.add_ride
      expect(trip.rides.size).to eq(2)
    end
  end

  describe '#age' do
    it 'displays the age of the hitchhiker at the time the trip was done' do
      trip.user.date_of_birth = 20.year.ago.to_date
      trip.departure = ( 1.year.ago - 200.days ).to_datetime
      expect(trip.age).to eq(18)
    end
  end

  describe '#average_speed' do
    it 'returns the average speed' do
      trip.distance = 5000 # meters
      allow(trip).to receive_messages(duration: 1.hour.to_i)
      expect(trip.average_speed).to eq('5 kmh')
    end
  end
end
