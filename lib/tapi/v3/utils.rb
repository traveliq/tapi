module TAPI

  module Utils

    module_function

    def coerce_date(date)
      case date
      when Date then date
      when String then parse_date(date)
      when NilClass then nil
      else
        raise TypeError, "cannot coerce #{date.inspect}", caller
      end        
    end

    def parse_date(date)
      Date.strptime(date, '%d.%m.%Y')
    rescue ArgumentError
      begin
        Date.strptime(date, '%Y-%m-%d')
      rescue ArgumentError
        raise TypeError, "cannot parse #{date.inspect}", caller
      end
    end

    def append_query(url, hash)
      pairs = hash.to_a.sort {|a, b| a.first.to_s <=> b.first.to_s}
      query_elements =
        pairs.inject([]) do |accumulator, key_value|
        key, value = key_value
        case value
        when Array
          value.each do |v|
            accumulator << "#{key}[]=#{v}"
          end
        else
          accumulator << "#{key}=#{value}"
        end
        accumulator
      end
      if query_elements.any?
        attributes = URI.escape(query_elements.join('&'))
        join_char = url.include?('?') ? '&' : '?'
        url + join_char + attributes 
      else
        url
      end
    end

    def symbolize_keys(data)
      case data
      when Hash
        data.inject({}){|acc, pair| acc[pair.first.to_sym] = symbolize_keys(pair.last); acc}
      when Array
        data.map {|e| symbolize_keys(e)}
      else
        data
      end
    end
    
    
  end  
end
