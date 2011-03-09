module TAPI

  module Validations

    def has_errors?
      errors.any?
    end

    def add_error(name, message)
      (errors[name] ||= []) << message
    end

    def validations
      @validations ||= []
    end

    def inherited_validations
      if superclass.respond_to?(:validations)
        superclass.validations + validations
      else
        validations
      end
    end

    def validate(&block)
      validations << block
    end

    def validates_presence_of(name, message)
      validate do
        if send(name).blank?
          add_error(name, message)
        end
      end
    end

    def validates_date_format_of(name, message)
      validate do
        begin
          Utils.coerce_date(send(name))
        rescue TypeError
          add_error name, message
        end
      end
    end    

    def validates_numericality_of(name, message)
      validate do
        number = send(name)
        unless number.is_a?(Fixnum) || /^[0-9]+$/ =~ number
          add_error name, message
        end
      end
    end    

  end
  
end
