module TAPI

  class Error < RuntimeError
    attr_accessor :response_code, :request_url, :response_body

    def to_s
      "Status code: #{response_code}\nRequest url: #{request_url}\n\n\n#{response_body}"
    end
  end

  class BadRequestError < Error
  end

  class NotFoundError < Error
  end

  class ExpiredError < Error
  end

  class MovedError < Error
  end

  class InternalServerError < Error
  end

end
