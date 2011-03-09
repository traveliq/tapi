# -*- coding: utf-8 -*-
module TAPI
  module V3
    module Flights
      class Search < TAPI::V3::GenericSearch
        
        AIRPORTCODEEXPR = /^[\w]{3}$/
        
        attr_accessor :origin, :destination, :comfort
        attr_reader :leaves_on, :returns_on, :one_way, :adults, :children, :infants

        def leaves_on=(date)
          @leaves_on = coerce_date(date) rescue nil
        end

        def returns_on=(date)
          @returns_on = coerce_date(date) rescue nil
        end

        def one_way=(value)
          @one_way = value.to_s == 'true'
        end

        def adults=(value)
          @adults = value.to_i
        end

        def children=(value)
          @children = value.to_i
        end

        def infants=(value)
          @infants = value.to_i
        end
        
        validates_numericality_of :adults, "Bitte wählen Sie die Anzahl der Erwachsenen."
        validates_numericality_of :children, "Bitte wählen Sie die Anzahl der Kinder."
        validates_numericality_of :infants, "Bitte wählen Sie die Anzahl der Babies."

        validate do
          if leaves_on and leaves_on < Date.today
            add_error :leaves_on, "Abflug muss in der Zukunft liegen."
          end

          if returns_on and leaves_on and returns_on < leaves_on
            add_error :returns_on, "Rückflug muss später als der Hinflug sein."
          end

          if leaves_on.nil?
            add_error :leaves_on, "Bitte wählen Sie ein gültiges Abflugdatum aus."
          end

          if one_way.to_s == 'true' and not returns_on.to_s.empty?
            add_error :returns_on, "Bitte wählen Sie entweder One-Way oder ein Rückflugdatum aus."
          end
          
          if one_way.to_s != 'true' and returns_on.to_s.empty?
            add_error :returns_on, "Bitte wählen Sie ein gültiges Datum aus."
          end

          if adults.to_i < infants.to_i
            add_error :passengers, "Die Anzahl der Erwachsenen muss mindestens gleich der Babies sein."
          end

          if adults.to_i < 1
            add_error :passengers, "Es muss mindestens ein Erwachsener fliegen."
          end

          unless AIRPORTCODEEXPR =~ origin.to_s            
            add_error :origin, "Bitte wählen Sie einen Startflughafen."
          end
          
          unless AIRPORTCODEEXPR =~ destination.to_s
            add_error :destination, "Bitte wählen Sie einen Zielflughafen."
          end
          
          unless /^(E|B|EB|BE)$/ =~ comfort
            add_error :passengers, "Bitte geben Die einen gültigen Code für den Comfort an."
          end
          
          unless origin.to_s.empty? or destination.to_s.empty?
            if origin == destination
              add_error :destination, "Bitte wählen Sie unterschiedliche Start- und Zielflughäfen."
            end
          end
        end

        def item_path
          'flights'
        end
        
        def initialize(options = {})
          @errors = {}
          self.origin = options[:origin]
          self.destination = options[:destination]
          self.leaves_on = options[:leaves_on]
          self.returns_on = options[:returns_on]
          self.one_way = options[:one_way]
          self.adults = options[:adults] || 1
          self.children = options[:children] || 0
          self.infants = options[:infants] || 0
          self.comfort = (options[:comfort] || "E").upcase
        end

        def parameters
          {
            :key => config[:key],
            :format => 'json',
            :origin => origin,
            :destination => destination,
            :leaves_on => leaves_on.to_s,
            :returns_on => returns_on.to_s,
            :one_way => one_way,
            :adults => adults,
            :children => children,
            :infants => infants,
            :comfort => comfort
          }
        end

      end
    end
  end
end
