
module BeValidAsset

  # Abstrace base class for other matchers
  class BeValidBase

    private

      def check_net_enabled
        if ENV["NONET"] == 'true'
          raise Spec::Example::ExamplePendingError.new('Network tests disabled')
        end
      end

      def validate(query_params)
        response = get_validator_response(query_params)

        markup_is_valid = response['x-w3c-validator-status'] == 'Valid'
        @message = ''
        unless markup_is_valid
          fragment.split($/).each_with_index{|line, index| @message << "#{'%04i' % (index+1)} : #{line}#{$/}"} if Configuration.display_invalid_content
          REXML::Document.new(response.body).root.each_element('//m:error') do |e|
            @message << "#{error_line_prefix}: line #{e.elements['m:line'].text}: #{e.elements['m:message'].get_text.value.strip}\n"
          end
        end
        return markup_is_valid
      end

      def get_validator_response(params = {})
        boundary = Digest::MD5.hexdigest(Time.now.to_s)
        data = encode_multipart_params(boundary, params)
        if Configuration.enable_caching
          digest = Digest::MD5.hexdigest(params.to_s)
          cache_filename = File.join(Configuration.cache_path, digest)
          if File.exist? cache_filename
            response = File.open(cache_filename) {|f| Marshal.load(f) }
          else
            response = call_validator( data, boundary )
            File.open(cache_filename, 'w') {|f| Marshal.dump(response, f) } if response.is_a? Net::HTTPSuccess
          end
        else
          response = call_validator( data, boundary)
        end
        raise "HTTP error: #{response.code}" unless response.is_a? Net::HTTPSuccess
        return response
      end

      def call_validator(data, boundary)
        check_net_enabled
        return Net::HTTP.start(validator_host).post2(validator_path, data, "Content-type" => "multipart/form-data; boundary=#{boundary}" )
      end

      def encode_multipart_params(boundary, params = {})
        ret = ''
        params.each do |k,v|
          unless v.empty?
            ret << "\r\n--#{boundary}\r\n"
            ret << "Content-Disposition: form-data; name=\"#{k.to_s}\"\r\n\r\n"
            ret << v
          end
        end
        ret << "\r\n--#{boundary}--\r\n"
        ret
      end
  end
end