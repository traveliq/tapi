# -*- coding: utf-8 -*-
module TAPI
  module V3
    module Hotels
      class Search < TAPI::V3::GenericSearch
        attr_accessor :expired

        attr_reader :arrival_date, :departure_date, :city_id, :region_id, :hotel_id
        attr_reader :room_configuration, :single_rooms_count, :double_rooms_count
        
        validates_numericality_of :single_rooms_count, "Bitte wählen Sie die Anzahl der Einzelzimmer."
        validates_numericality_of :double_rooms_count, "Bitte wählen Sie die Anzahl der Doppelzimmer."

        validates_presence_of :arrival_date, "Bitte wählen Sie ein gültiges Datum."
        validates_presence_of :departure_date, "Bitte wählen Sie ein gültiges Datum."

        validate do
          if arrival_date and arrival_date < Date.today
            add_error :arrival_date, "Das Anreisedatum darf nicht in der Vergangenheit liegen."
          end

          if single_rooms_count == 0 and double_rooms_count == 0
            add_error :room_configuration, "Bitte mindestens ein Zimmer angeben."
          end

          if (single_rooms_count + double_rooms_count) > 3
            add_error :room_configuration, "Bitte nicht mehr als 3 Zimmer angeben."
          end

          if arrival_date and departure_date and departure_date <= arrival_date
            add_error :departure_date, "Das Abreisedatum muss mindestens einen Tag nach der Ankunft liegen."
          end

          if city_id.blank? and region_id.blank? and hotel_id.blank?
            add_error :city_id, "Bitte geben Sie den gewünschten Aufenthaltsort an."
          end

        end
        
        class << self
          
          def parse_room_configuration(str)
            rooms_strings = str.split('][').map {|r| r.gsub(/\]|\[/, '').split('|')}
            raise ArgumentError, "#{str} is not a valid room configuration hash !" if rooms_strings.length > 3 ||  rooms_strings.empty?
            room_collection = {}
            rooms = rooms_strings.each_with_index do |guests, i|
              room_collection[i + 1] ||= {}
              guests.each do |g|
                case g
                when 'A'
                  room_collection[i + 1]['adults'] ||= 0
                  room_collection[i + 1]['adults'] += 1
                when /\d/
                  room_collection[i + 1]['child'] ||= {}
                  last_key = room_collection[i + 1]['child'].keys.min || 0
                  room_collection[i + 1]['child'][last_key + 1] = g.to_i
                else
                  raise ArgumentError, "#{str} is not a valid room configuration hash !"
                end
              end
            end
            room_collection
          end

        end # class

        def initialize(options = {})
          @errors = {}
          @single_rooms_count = 0
          @double_rooms_count = 0

          self.arrival_date = options[:arrival_date]
          self.departure_date = options[:departure_date]

          self.city_id = options[:city_id]
          self.region_id = options[:region_id]
          self.hotel_id = options[:hotel_id]

          if options[:room_configuration].blank?
            self.single_rooms_count = options[:single_rooms_count] || 1
            self.double_rooms_count = options[:double_rooms_count] || 0
          else
            self.room_configuration = options[:room_configuration]
          end
        end

        def item_path
          'hotels'
        end

        def state
          @client.status_detailed.state if @client
        end

        def location
          case
          when city_id then city
          when region_id then region
          when hotel_id then hotel
          end
        end
        
        def location_type
          case
          when city_id then :city
          when region_id then :region
          when hotel_id then :hotel
          end
        end

        def location_id
          city_id || region_id || hotel_id
        end

        def arrival_date=(date)
          @arrival_date = coerce_date(date)
        rescue TypeError => e
          Client.logger.debug e.message
          Client.logger.debug e.backtrace.join("\n")
        end

        def departure_date=(date)
          @departure_date = coerce_date(date)
        rescue TypeError => e
          Client.logger.debug e.message
          Client.logger.debug e.backtrace.join("\n")
        end

        def city_id=(id)
          @city_id = id.to_i unless id.to_s.empty?
        end

        def region_id=(id)
          @region_id = id.to_i unless id.to_s.empty?
        end

        def hotel_id=(id)
          @hotel_id = id.to_i unless id.to_s.empty?
        end

        def city
          @city ||= get("/locations/cities/#{city_id}").city unless city_id.to_s.empty?
        end

        def region
          @region ||= get("/locations/regions/#{region_id}").region unless region_id.to_s.empty?
        end

        def hotel
          @hotel ||= get("/locations/hotels/#{hotel_id}").hotel unless hotel_id.to_s.empty?
        end

        def room_configuration=(config)
          @room_configuration = config
          rooms = Search.parse_room_configuration(config).values

          @single_rooms_count = rooms.count { |room| room['adults'] == 1 }
          @double_rooms_count = rooms.count { |room| room['adults'] == 2 }
        end

        def single_rooms_count=(count)
          @single_rooms_count = Integer(count)
          update_room_configuration!
        end

        def double_rooms_count=(count)
          @double_rooms_count = Integer(count)
          update_room_configuration!
        end

        def update_room_configuration!
          @room_configuration = ('[A]' * single_rooms_count) + ('[A|A]' * double_rooms_count)
        end

        def to_param
          {
            :location_type => location_type,
            :location_id => location_id,
            :arrival_date => arrival_date.to_s,
            :departure_date => departure_date.to_s,
            :single_rooms_count => single_rooms_count,
            :double_rooms_count => double_rooms_count
          }
        end
        
        def parameters
          {
            :key => config[:key],
            :format => 'json',
            :city_id => city_id,
            :region_id => region_id,
            :hotel_id => hotel_id,
            :arrival_date => arrival_date.to_s,
            :departure_date => departure_date.to_s,
            :room_configuration => room_configuration
          }
        end

        # create a hotel search with the same parameters
        # for a given hotel
        def hotel_search(result_or_hotel_id)
          hotel_id = result_or_hotel_id.is_a?(Fixnum) ? result_or_hotel_id : result_or_hotel_id.hotel_id
          params = parameters
          params.delete(:city_id)
          params.delete(:region_id)
          params[:hotel_id] = hotel_id
          TAPI::V3::Hotels::Search.new(params)
        end
        
      end
    end
  end
end
