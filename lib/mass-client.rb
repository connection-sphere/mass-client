require 'uri'
require 'net/http'
require 'json'
require 'blackstack-core'
require 'simple_cloud_logging'
require 'simple_command_line_parser'
require 'colorize'
require 'timeout'
require 'base64'
require 'adspower-client'
require 'aws-sdk-s3' # Ensure the AWS SDK for S3 is installed
require 'mini_magick' # https://github.com/connection-sphere/docs/issues/368

# mass client configuration
module Mass
    @@js_path
    @@drownload_path
    @@api_client
    
    # DEPRECATED
    @@s3_bucket
    @@s3_region
    @@s3_access_key_id
    @@s3_secret_access_key
    @@s3

    # https://github.com/connection-sphere/developer-documentation/issues/828
    @@my_s3_api_key
    @@my_s3_url

    # set the ConnectionSphere API client
    #
    # Parameters:
    #
    # api_key: Mandatory. The API key of your ConnectionSphere account.
    # subaccount: Optional. The name of the subaccount you want to work with. If you provide a subaccount, the SDK will call the master to get the URL and port of the subaccount. Default is nil.
    # 
    # api_url: Optional. The URL of the ConnectionSphere API. Default is 'https://connectionsphere.com'.
    # api_port: Optional. The port of the ConnectionSphere API. Default is 443.
    # api_version: Optional. The version of the ConnectionSphere API. Default is '1.0'.
    #
    # backtrace: Optional. If true, the backtrace of the exceptions will be returned by the access points. If false, only an error description is returned. Default is false.
    # 
    # js_path: Optional. The path to the JavaScript file to be used by the SDK. Default is nil.
    # download_path: Optional. The path to the download folder(s) to be used by the SDK. Default is [].
    #
    # s3_region, s3_access_key_id, s3_secret_access_key, s3_bucket: Defining AWS S3 parameter for storing files at the client-side.
    #
    def self.set(
        api_key: ,
        subaccount: nil,

        api_url: 'https://connectionsphere.com', 
        api_port: 443,
        api_version: '1.0',

        backtrace: false,

        js_path: nil, 
        download_path: [],

        # DEPRECATED
        s3_region: nil,
        s3_access_key_id: nil,
        s3_secret_access_key: nil,
        s3_bucket: nil,

        # https://github.com/connection-sphere/developer-documentation/issues/828
        my_s3_api_key: nil,
        my_s3_url: nil
    )
        # call the master to get the URL and port of the subaccount.
        BlackStack::API.set_client(
            api_key: api_key,
            api_url: api_url,
            api_port: api_port,
            api_version: api_version,
            backtrace: backtrace
        )
        
        if subaccount
            params = { 'name' => subaccount }
            ret = BlackStack::API.post(
                endpoint: "resolve/get",
                params: params
            )

            raise "Error initializing client: #{ret['status']}" if ret['status'] != 'success'
            
            # call the master to get the URL and port of the subaccount.
            BlackStack::API.set_client(
                api_key: ret['api_key'],
                api_url: ret['url'],
                api_port: ret['port'],
                api_version: api_version,
                backtrace: backtrace
            )
        end

        # validate: download_path must be a string or an arrow of strings
        if download_path.is_a?(String)
            raise ArgumentError.new("The parameter 'download_path' must be a string or an array of strings.") if download_path.to_s.empty?
        elsif download_path.is_a?(Array)
            download_path.each { |p|
                raise ArgumentError.new("The parameter 'download_path' must be a string or an array of strings.") if p.to_s.empty?
            }
        else
            raise ArgumentError.new("The parameter 'download_path' must be a string or an array of strings.")
        end

        @@js_path = js_path
        @@download_path = download_path

        @@s3 = nil
        @@s3_region = s3_region
        @@s3_access_key_id = s3_access_key_id
        @@s3_secret_access_key = s3_secret_access_key
        @@s3_bucket = s3_bucket

        # Initialize the S3 client
        if (
            @@s3_region
            @@s3_access_key_id
            @@s3_secret_access_key
            @@s3_bucket
        )
            @@s3 = Aws::S3::Client.new(
                region: @@s3_region,
                access_key_id: @@s3_access_key_id,
                secret_access_key: @@s3_secret_access_key
            )
        end

        # Initialize My.S3 API key
        @@my_s3_api_key = my_s3_api_key
        @@my_s3_url = my_s3_url
    end

    def self.download_path
        @@download_path
    end

    def self.js_path
        @@js_path
    end

    def self.s3_region
        @@s3_region
    end

    def self.s3_access_key_id
        @@s3_access_key_id
    end

    def self.s3_secret_access_key
        @@s3_secret_access_key
    end

    def self.s3_bucket
        @@s3_bucket
    end

    def self.s3
        @@s3
    end

    def self.my_s3_api_key
        @@my_s3_api_key
    end

    def self.my_s3_url
        @@my_s3_url
    end

end # module Mass

# base classes
require_relative './/base-line/channel'

require_relative './/base-line/profile_type'
require_relative './/base-line/source_type'
require_relative './/base-line/enrichment_type'
require_relative './/base-line/outreach_type'
require_relative './/base-line/data_type'

require_relative './/base-line/headcount'
require_relative './/base-line/industry'
require_relative './/base-line/location'
require_relative './/base-line/revenue'
require_relative './/base-line/ai_agent'
require_relative './/base-line/tag'
require_relative './/base-line/profile'

require_relative './/base-line/source'
require_relative './/base-line/job'
require_relative './/base-line/event'

require_relative './/base-line/outreach'
require_relative './/base-line/enrichment'

require_relative './/base-line/unsubscribe'

require_relative './/base-line/company'
#require_relative './/base-line/company_data'
#require_relative './/base-line/company_industry'
#require_relative './/base-line/company_naics'
#require_relative './/base-line/company_sic'
#require_relative './/base-line/company_tag'

require_relative './/base-line/lead'
#require_relative './/base-line/lead_data'
#require_relative './/base-line/lead_tag'

require_relative './/base-line/inboxcheck'
require_relative './/base-line/connectioncheck'
require_relative './/base-line/rule'
require_relative './/base-line/request'

# first line of children
require_relative './/first-line/profile_api'
require_relative './/first-line/profile_mta'
require_relative './/first-line/profile_rpa'


