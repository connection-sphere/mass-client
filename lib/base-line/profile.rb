module Mass 
    class Profile < BlackStack::Base
        attr_accessor :type

        # DROPBOX LOCKFILE PARAMETERS
        LOCKFILE_PATH = '/tmp/dropbox_upload.lock' # Path to your lockfile
        LOCK_TIMEOUT = 60 # Maximum time in seconds to wait for the lock

        # DROPBOX LOCKFILE FUNCTIONS
        def acquire_lock
            begin
                Timeout.timeout(LOCK_TIMEOUT) do
                # Wait until the lockfile can be created (i.e., it's not already taken)
                while File.exist?(LOCKFILE_PATH)
                    sleep 0.1
                end
                # Create the lockfile
                File.open(LOCKFILE_PATH, 'w') {}
                end
            rescue Timeout::Error
                raise "Timeout while waiting for lockfile."
            end
        end

        def release_lock
            File.delete(LOCKFILE_PATH) if File.exist?(LOCKFILE_PATH)
        end

        # Function to upload a file to Amazon S3 and get its public URL
        def upload_file_to_s3(file_path, s3_key)
            if @s3
                # Upload the file
                Mass.s3.put_object(
                    bucket: Mass.s3_bucket, 
                    key: s3_key, 
                    body: File.open(file_path)
                )
                # Generate the public URL
                public_url = "https://#{Mass.s3_bucket}.s3.amazonaws.com/#{s3_key}"
                # return
                return public_url
            elsif Mass.my_s3_api_key && Mass.my_s3_url
                my_s3_upload_file(file_path, s3_key)
                return my_s3_public_url_for(s3_key)
            end
        end
  
        # Function to create a folder in S3
        def create_s3_folder(folder_name)
            if @s3
                Mass.s3.put_object(
                    bucket: Mass.s3_bucket, 
                    key: "#{folder_name}/"
                )
                return true
            elsif Mass.my_s3_api_key && Mass.my_s3_url
                ensure_my_s3_path_exists(folder_name)
                return true
            end 
        end

        #
        #
        #

        # download image from Selenium using JavaScript and upload to Dropbox 
        # return the URL of the screenshot
        # 
        # Parameters:
        # - url: Internet address of the image to download from the website and upload to dropbox.
        # - dropbox_folder: Dropbox folder name to store the image.
        #                
        def download_image_0(url, dropbox_folder = nil, s3_optimization: true)
            raise "Either dropbox_folder parameter or self.desc['id_account'] are required." if dropbox_folder.nil? && self.desc['id_account'].nil?
            dropbox_folder = self.desc['id_account'] if dropbox_folder.nil?
            
            # Parameters
            id = SecureRandom.uuid
            
            # JavaScript to get base64 image data
            js0 = "
                function getImageBase64(imageSrc) {
                return new Promise(async (resolve, reject) => {
                    try {
                    const response = await fetch(imageSrc);
                    const blob = await response.blob();
                    const reader = new FileReader();
                    reader.onloadend = function() {
                        resolve(reader.result);
                    };
                    reader.onerror = function(error) {
                        reject(error);
                    };
                    reader.readAsDataURL(blob);
                    } catch (error) {
                    reject(error);
                    }
                });
                }
                return getImageBase64('#{url}');
            "
            
            # Execute JavaScript and get base64 image data
            base64_image = driver.execute_script(js0)
            raise "Failed to retrieve image data from URL: #{url}" if base64_image.nil?
            
            # Extract MIME type and base64 data
            mime_type_match = base64_image.match(/^data:image\/([a-zA-Z0-9.+-]+);base64,/)
            if mime_type_match
                mime_subtype = mime_type_match[1] # e.g., 'png', 'jpeg', 'gif'
                # Map common MIME subtypes to file extensions
                extension = case mime_subtype
                            when 'jpeg' then 'jpg'
                            else mime_subtype
                            end
                # Remove the data URL prefix
                image_data = base64_image.sub(/^data:image\/[a-zA-Z0-9.+-]+;base64,/, '')
            else
                raise "Unsupported or invalid image data format."
            end
            
            # Update filename and paths
            filename = "#{id}.#{extension}"
            tmp_paths = if Mass.download_path.is_a?(String)
                            ["#{Mass.download_path}/#{filename}"]
                        elsif Mass.download_path.is_a?(Array)
                            Mass.download_path.map { |s| "#{s}/#{filename}" }
                        else
                            raise "Invalid Mass.download_path configuration."
                        end
            
            # Save the image to the first available path
            tmp_path = tmp_paths.find { |path| File.writable?(File.dirname(path)) }
            raise "No writable path found in #{tmp_paths.join(', ')}." if tmp_path.nil?
            
            File.open(tmp_path, 'wb') do |file|
                file.write(Base64.decode64(image_data))
            end
            
            # AWS/S3 optimization - Reduce the resolution of the screenshot
            # Reference: https://github.com/MassProspecting/docs/issues/368
            if s3_optimization
                image = MiniMagick::Image.open(tmp_path)
                image.format "jpeg"
                image.strip  # Remove all profiles and comments
                image.quality "50" # Apply compression quality setting (for JPEG)
                image_ret = image.quality "10" # reduce the file size as well by compressing the image
                image.write(tmp_path)
            end # s3_optimization

            # Proceed with Dropbox operations
            year = Time.now.year.to_s.rjust(4, '0')
            month = Time.now.month.to_s.rjust(2, '0')
            folder = dropbox_folder #"/massprospecting.rpa/#{dropbox_folder}.#{year}.#{month}"
            path = "#{folder}/#{filename}"
            create_s3_folder(folder)

            # Upload the file to Dropbox
            ret = upload_file_to_s3(tmp_path, path)

            # Delete the local file
            File.delete(tmp_path)

            # Return the URL of the file in Dropbox
            # 
            # Add a timeout to wait the file is present in the cloud.
            # Reference: https://github.com/MassProspecting/docs/issues/320
            ret
        end
                
        # download image from Selenium using JavaScript and upload to Dropbox 
        # return the URL of the screenshot
        # 
        # Parameters:
        # - img: Selenium image element to download from the website and upload to dropbox.
        # - dropbox_folder: Dropbox folder name to store the image.
        #
        def download_image(img, dropbox_folder=nil)
            download_image_0(img.attribute('src'), dropbox_folder)
        end # def download_image

        #
        #
        #
        def self.object_name
            'profile'
        end

        def initialize(h)
            super(h)
            self.type = Mass::ProfileType.new(h['profile_type_desc']).child_class_instance
        end

        # convert the profile_type into the ruby class to create an instance.
        # example: Apollo --> Mass::ApolloAPI
        def class_name_from_profile_type
            profile_type = self.desc['profile_type']
            "Mass::#{profile_type}" 
        end

        # crate an instance of the profile type using the class defined in the `desc['name']` attribute.
        # override the base method
        def child_class_instance
            profile_type = self.desc['profile_type']
            key = self.class_name_from_profile_type
            raise "Source code of profile type #{profile_type} not found. Create a class #{key} in the folder `/lib` of your mass-sdk." unless Kernel.const_defined?(key)
            ret = Kernel.const_get(key).new(self.desc)
            return ret
        end
        
        # return true of the profile is running
        # if its profile type is rpa-access, then it will return true if the browser is running.
        # else, it will return always true.
        def running?
            if self.type.desc['access'].to_sym == :rpa
                c = AdsPowerClient.new(key: ADSPOWER_API_KEY)
                return c.check(self.desc['ads_power_id'])
            end
            return true
        end
        
        # Scrape the inbox of the profile.
        # Return a an array of hash descriptors of outreach records.
        # 
        # Parameters:
        # - limit: the maximum number of messages to scrape. Default: 100.
        # - only_unread: if true, then only the unread messages will be scraped. Default: true.
        # - logger: a logger object to log the process. Default: nil.
        #
        # Example of a hash descritor into the returned array:
        # ```
        # {
        #    # a scraped message is always a :performed message
        #    'status' => :performed,
        #    # what is the outreach type?
        #    # e.g.: :LinkedIn_DirectMessage
        #    # decide this in the child class.
        #    'outreach_type' => nil,
        #    # hash descriptor of the profile who is scraping the inbox
        #    'profile' => self.desc,
        #    # hash descriptor of the lead who is the conversation partner
        #    'lead' => nil,
        #    # if the message has been sent by the profile, it is :outgoing.
        #    # if the message has been sent by the lead, it is :incoming.
        #    'direction' => nil, 
        #    # the content of the message
        #    'subject' => nil,
        #    'body' => nil,
        # }
        # ```
        #
        def inboxcheck(limit: 100, only_unread:true, logger:nil)
            []
        end # def inboxcheck

        # Scrape the inbox of the profile.
        # Return a an array of hash descriptors of outreach records.
        # 
        # Parameters:
        # - limit: the maximum number of connections to scrape. Default: 100.
        # - logger: a logger object to log the process. Default: nil.
        #
        # Example of a hash descritor into the returned array:
        # ```
        # {
        #    # a scraped message is always a :performed message
        #    'status' => :performed,
        #    # what is the outreach type?
        #    # e.g.: :LinkedIn_ConnectionRequest
        #    # decide this in the child class.
        #    'outreach_type' => nil,
        #    # hash descriptor of the profile who is scraping the inbox
        #    'profile' => self.desc,
        #    # hash descriptor of the lead who is the conversation partner
        #    'lead' => nil,
        #    # if the message has been sent by the profile, it is :outgoing.
        #    # if the message has been sent by the lead, it is :incoming.
        #    'direction' => :accepted, 
        # }
        # ```
        #
        def connectioncheck(limit: 100, logger:nil)
            []
        end # def connectioncheck

        class MyS3Error < StandardError; end

        private

        def ensure_my_s3_path_exists(path)
            sanitized = path.to_s.strip.gsub(%r{^/+|/+$}, '')
            return true if sanitized.empty?

            current = ''
            sanitized.split('/').each do |segment|
                parent = current
                begin
                    my_s3_json_post('/create_folder.json', {
                        path: parent,
                        folder_name: segment
                    })
                rescue MyS3Error => e
                    raise unless e.message =~ /folder already exists/i
                end
                current = parent.empty? ? segment : [parent, segment].join('/').gsub(%r{/+}, '/').sub(%r{^/+}, '')
            end

            true
        end

        def my_s3_upload_file(local_path, remote_path)
            raise MyS3Error, 'Local file not found' unless File.file?(local_path)

            relative_path = File.dirname(remote_path.to_s)
            relative_path = '' if relative_path == '.'
            filename = File.basename(remote_path.to_s).to_s
            raise MyS3Error, 'Remote filename is required' if filename.strip.empty?

            uri = my_s3_uri_for('/upload.json')
            boundary = "----MassMyS3#{SecureRandom.hex(12)}"
            request = Net::HTTP::Post.new(uri)
            request['X-API-Key'] = my_s3_api_key!
            request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
            request.body = build_my_s3_multipart(boundary, relative_path, filename, local_path)

            response = my_s3_http(uri).request(request)
            json = parse_my_s3_json(response.body)
            return json if response.is_a?(Net::HTTPSuccess) && json['success']

            message = json.dig('error', 'message') || response.body
            raise MyS3Error, message
        end

        def my_s3_public_url_for(remote_path)
            dir = File.dirname(remote_path.to_s)
            dir = '' if dir == '.'
            filename = File.basename(remote_path.to_s)
            raise MyS3Error, 'Filename is required for public URL generation' if filename.to_s.strip.empty?

            response = my_s3_json_post('/get_public_url.json', {
                path: dir,
                filename: filename
            })

            response['public_url']
        end

        def build_my_s3_multipart(boundary, relative_path, filename, local_path)
            body = []
            body << "--#{boundary}\r\n"
            body << "Content-Disposition: form-data; name=\"path\"\r\n\r\n"
            body << "#{relative_path}\r\n"
            body << "--#{boundary}\r\n"
            body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
            body << "Content-Type: application/octet-stream\r\n\r\n"
            body << File.binread(local_path)
            body << "\r\n--#{boundary}--\r\n"
            body.join
        end

        def my_s3_json_post(endpoint, payload)
            uri = my_s3_uri_for(endpoint)
            request = Net::HTTP::Post.new(uri)
            request['Content-Type'] = 'application/json'
            request['X-API-Key'] = my_s3_api_key!
            request.body = JSON.generate(payload)

            response = my_s3_http(uri).request(request)
            json = parse_my_s3_json(response.body)
            return json if response.is_a?(Net::HTTPSuccess) && json['success']

            message = json.dig('error', 'message') || response.body
            raise MyS3Error, message
        end

        def parse_my_s3_json(body)
            return {} if body.nil? || body.strip.empty?
            JSON.parse(body)
        rescue JSON::ParserError
            raise MyS3Error, "Invalid JSON response: #{body}"
        end

        def my_s3_uri_for(endpoint)
            normalized = my_s3_base_url!
            URI.join(normalized, endpoint.to_s.sub(%r{^/+}, ''))
        end

        def my_s3_http(uri)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = uri.scheme == 'https'
            http
        end

        def my_s3_base_url!
            base = Mass.my_s3_url.to_s.strip
            raise MyS3Error, 'Mass.my_s3_url is not configured' if base.empty?
            base.end_with?('/') ? base : "#{base}/"
        end

        def my_s3_api_key!
            key = Mass.my_s3_api_key.to_s.strip
            raise MyS3Error, 'Mass.my_s3_api_key is not configured' if key.empty?
            key
        end

    end # class Profile
end # module Mass