# frozen-string-literal: true

#
class Roda
  module RodaPlugins
    # The drop_body plugin automatically drops the body and
    # Content-Type/Content-Length headers from the response if
    # the response status indicates that the response should
    # not include a body (response statuses 100, 101, 102, 204,
    # and 304).  For response status 205, the body and Content-Type
    # headers are dropped, but the Content-length header is set to
    # '0' instead of being dropped.
    module DropBody
      module ResponseMethods
        DROP_BODY_STATUSES = [100, 101, 102, 204, 205, 304].freeze
        RodaPlugins.deprecate_constant(self, :DROP_BODY_STATUSES)

        # If the response status indicates a body should not be
        # returned, use an empty body and remove the Content-Length
        # and Content-Type headers.
        def finish
          r = super
          case r[0]
          when 100, 101, 102, 204, 304
            r[2] = EMPTY_ARRAY
            h = r[1]
            h.delete("Content-Length")
            h.delete("Content-Type")
          when 205
            r[2] = EMPTY_ARRAY
            h = r[1]
            h["Content-Length"] = '0'
            h.delete("Content-Type")
          end
          r
        end
      end
    end

    register_plugin(:drop_body, DropBody)
  end
end
