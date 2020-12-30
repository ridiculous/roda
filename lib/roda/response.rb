# frozen-string-literal: true

class Roda
  # Base class used for Roda responses.  The instance methods for this
  # class are added by Roda::RodaPlugins::Base::ResponseMethods, the class
  # methods are added by Roda::RodaPlugins::Base::ResponseClassMethods.
  class RodaResponse
    @roda_class = ::Roda
  end

  module RodaPlugins
    module Base
      # Class methods for RodaResponse
      module ResponseClassMethods
        # Reference to the Roda class related to this response class.
        attr_accessor :roda_class

        # Since RodaResponse is anonymously subclassed when Roda is subclassed,
        # and then assigned to a constant of the Roda subclass, make inspect
        # reflect the likely name for the class.
        def inspect
          "#{roda_class.inspect}::RodaResponse"
        end
      end

      # Instance methods for RodaResponse
      module ResponseMethods
        DEFAULT_HEADERS = {"Content-Type" => "text/html".freeze}.freeze

        # The body for the current response.
        attr_reader :body

        # The hash of response headers for the current response.
        attr_reader :headers

        # The status code to use for the response.  If none is given, will use 200
        # code for non-empty responses and a 404 code for empty responses.
        attr_accessor :status

        # Set the default headers when creating a response.
        def initialize
          @headers = {}
          @body    = []
          @length  = 0
        end

        # Return the response header with the given key. Example:
        #
        #   response['Content-Type'] # => 'text/html'
        def [](key)
          @headers[key]
        end

        # Set the response header with the given key to the given value.
        #
        #   response['Content-Type'] = 'application/json'
        def []=(key, value)
          @headers[key] = value
        end

        # The default headers to use for responses.
        def default_headers
          DEFAULT_HEADERS
        end

        # Whether the response body has been written to yet.  Note
        # that writing an empty string to the response body marks
        # the response as not empty. Example:
        #
        #   response.empty? # => true
        #   response.write('a')
        #   response.empty? # => false
        def empty?
          @body.empty?
        end

        # Return the rack response array of status, headers, and body
        # for the current response.  If the status has not been set,
        # uses the return value of default_status if the body has
        # been written to, otherwise uses a 404 status.
        # Adds the Content-Length header to the size of the response body.
        #
        # Example:
        #
        #   response.finish
        #   #  => [200,
        #   #      {'Content-Type'=>'text/html', 'Content-Length'=>'0'},
        #   #      []]
        def finish
          b = @body
          set_default_headers
          h = @headers

          if b.empty?
            s = @status || 404
            if (s == 304 || s == 204 || (s >= 100 && s <= 199))
              h.delete("Content-Type")
            elsif s == 205
              h.delete("Content-Type")
              h["Content-Length"] = '0'
            else
              h["Content-Length"] ||= '0'
            end
          else
            s = @status || default_status
            h["Content-Length"] ||= @length.to_s
          end

          [s, h, b]
        end

        # Return the rack response array using a given body.  Assumes a
        # 200 response status unless status has been explicitly set,
        # and doesn't add the Content-Length header or use the existing
        # body.
        def finish_with_body(body)
          set_default_headers
          [@status || default_status, @headers, body]
        end

        # Return the default response status to be used when the body
        # has been written to. This is split out to make overriding
        # easier in plugins.
        def default_status
          200
        end

        # Show response class, status code, response headers, and response body
        def inspect
          "#<#{self.class.inspect} #{@status.inspect} #{@headers.inspect} #{@body.inspect}>"
        end

        # Set the Location header to the given path, and the status
        # to the given status.  Example:
        #
        #   response.redirect('foo', 301)
        #   response.redirect('bar')
        def redirect(path, status = 302)
          @headers["Location"] = path
          @status  = status
          nil
        end

        # Return the Roda class related to this response.
        def roda_class
          self.class.roda_class
        end

        # Write to the response body.  Returns nil.
        #
        #   response.write('foo')
        def write(str)
          s = str.to_s
          @length += s.bytesize
          @body << s
          nil
        end

        private

        # For each default header, if a header has not already been set for the
        # response, set the header in the response.
        def set_default_headers
          h = @headers
          default_headers.each do |k,v|
            h[k] ||= v
          end
        end
      end
    end
  end
end
