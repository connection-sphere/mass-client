module Mass
    class Source < BlackStack::Base
        attr_accessor :type

        def self.object_name
            'source'
        end

        def initialize(h)
            super(h)
            self.type = Mass::SourceType.new(h['source_type_desc']).child_class_instance
        end

        # convert the source_type into the ruby class to create an instance.
        # example: Apollo --> Mass::ApolloAPI
        def class_name_from_source_type
            source_type = self.desc['source_type']
            "Mass::#{source_type}" 
        end

        # crate an instance of the profile type using the class defined in the `desc['name']` attribute.
        # override the base method
        def child_class_instance
            source_type = self.desc['source_type']
            key = self.class_name_from_source_type
            raise "Source code of souurce type #{source_type} not found. Create a class #{key} in the folder `/lib` of your mass-sdk." unless Kernel.const_defined?(key)
            ret = Kernel.const_get(key).new(self.desc)
            return ret
        end

        # If the profile `access` is not `:rpa`, raise an exception.
        # Return `true` if the `url` is valid.
        # Return `false` if the `url` is not valid. 
        #
        # Overload this method in the child class.
        # 
        def valid_source_url?(url:)
            # If the profile `access` is not `:rpa`, raise an exception.
            raise "The method `valid_source_url?` is not allowed for #{self.profile_type.desc['access'].to_s} access." if self.profile_type.desc['access'] != :rpa
            # Return `true` if the `url` is valid.
            # Return `false` if the `url` is not valid. 
            true
        end

        # Return the same URL in a normalized form:
        # - remove all GET parameters.
        # - remove all trailing slashes.
        #
        # If the profile `access` is not `:rpa`, raise an exception.
        # If the `url` is not valid, raise an exception.
        # Return the normalized URL.
        #
        # Overload this method in the child class.
        #
        def normalized_source_url(url:)
            # If the profile `access` is not `:rpa`, raise an exception.
            raise "The method `normalized_source_url` is not allowed for #{self.profile_type.desc['access'].to_s} access." if self.profile_type.desc['access'] != :rpa
            # If the `url` is not valid, raise an exception.
            raise "The URL is not valid." if !self.valid_source_url?(url: url)
            # Return the same URL in a normalized form:
            # - remove all GET parameters.
            # - remove all trailing slashes.
            url = url.gsub(/\?.*$/, '').strip
            url = ret.gsub(/\/+$/, '')
            # Return the normalized URL.
            url
        end

        # If the profile `access` is not `:api`, raise an exception.
        # Parameter `params` must be a hash.
        # Return `true` if the `params` are valid.
        # Return `false` if the `params` are not valid. 
        def valid_source_params?(params:)
            # If the profile `access` is not `:api`, raise an exception.
            raise "The method `valid_source_params?` is not allowed for #{self.profile_type.desc['access'].to_s} access." if self.profile_type.desc['access'] != :api
            # Parameter `params` must be a hash.
            raise "The parameter `params` must be a hash." if !params.is_a?(Hash)
            # Return `true` if the `params` are valid.
            # Return `false` if the `params` are not valid. 
            true
        end

        # return array of event elements
        def event_elements(job:)
          raise "The method `event_elements` is not implemented for #{self.class.name}."
        end

        # scroll down the page until N event elements are showed up
        def show_up_event_elements(job:, event_limit:, max_scrolls:, take_screenshots: false, logger:nil)
            l = logger || BlackStack::DummyLogger.new(nil)
            driver = job.profile.driver
            # scroll down
            i = 0
            prev_n_events = 0
            security_height = 150  
            lis = self.event_elements(job: job)
            n_events = lis.size
            while (i<max_scrolls || n_events>prev_n_events) && n_events<event_limit
                i += 1

                prev_n_events = n_events
                lis = self.event_elements(job: job)
                n_events = lis.size

                # scroll down the exact height of the viewport or the feed container
                # reference: https://stackoverflow.com/questions/1248081/how-to-get-the-browser-viewport-dimensions
                l.logs "Scrolling down (#{i.to_s.blue}/#{max_scrolls.to_s.blue} - #{n_events.to_s.blue}/#{event_limit.to_s.blue} events showed up)... "
                step = self.desc['scrolling_step'] + rand(self.desc['scrolling_step_random'].to_i)

                # old DOM
                driver.execute_script("window.scrollTo(0, #{i.to_s}*#{step})")

                # new DOM
                # Use a more robust script: compute a rounded pixel amount and try to scroll
                # the main/feed container first (typical for SPA like LinkedIn). Fall back to
                # document.scrollingElement or window if necessary.
                script = <<~JS
                    var amount = Math.round(#{i} * #{step});
                    var el = document.querySelector('main') || document.querySelector('div[role="main"]') || document.querySelector('div[aria-label="Feed"]') || document.scrollingElement || document.documentElement || document.body;
                    if (el && typeof el.scrollTo === 'function') {
                        el.scrollTo(0, amount);
                    } else {
                        window.scrollTo(0, amount);
                    }
                JS
                driver.execute_script(script)
                sleep(5)
                l.logf "done".green

                # Save money - Disable jobs screenshots
                # https://github.com/connection-sphere/docs/issues/494
                #
                # screenshot
                l.logs 'Screenshot... '
                if take_screenshots
                    job.desc['screenshots'] << job.profile.screenshot if job.profile.desc['allow_browser_to_download_multiple_files']
                    l.logf 'done'.green + " (#{job.desc['screenshots'].size.to_s.blue} total)"
                else
                    l.no
                end
            end # while
            # If we exited because we reached the maximum number of scrolls
            if i >= max_scrolls && n_events < event_limit
                raise "Maximum scrolls (#{max_scrolls}) reached. Only #{n_events} events found."
            end
        end

        # Return a hash desriptor of the events found.
        #
        # Parameters:
        # - If the profile `access` is `:rpa`, then the `bot_driver` parameter is mandatory.
        # - If the profile `access` is `:api`, then the `api_key` parameter is mandatory.
        #
        # - If the profile `access` is `:mta`, raise an exception.
        #
        # - If the profile `access` is `:rpa`, then the `bot_url` parameter is mandatory, and it must be a valid URL.
        # - If the profile `access` is `:api`, then the `api_params` parameter is mandatory and it must be a hash.
        # 
        # - The `event_count` is for scrolling down (or perform any other required action) until finding `event_count` events.
        #
        # Output:
        # {
        #    'status' => :performed, # if it is not 'success', then it is an error description.
        #    'snapshot' => 'https://foo.com/snapshot.png'
        #    'screenshots' => [
        #        # array of URLs to screenshots
        #    ],
        #    'events' => [
        #        'url' => 'https://facebook.com/john-doe/posts/12345', # normalized URL of the event
        #        'title' => 'Join my Facebook Community!'
        #        'content' => 'My name is John Doe and I invite everyone to join my Facebook Community: facebook.com/groups/john-doe-restaurants!',
        #        'pictures' => [
        #            # array of URLs to pictures scraped from the post and uploaded to our DropBox.
        #        ],
        #        'lead' => {
        #            'name' => 'John Doe',
        #            'url' => 'https://facebook.com/john-doe',
        #            'headline' => "Founder & CEO at Doe's Restaurants", 
        #            'picture' => 'https://foo.com/john-doe.png'
        #        }
        #    ],
        # }
        # 
        def do(job:, logger:nil)
            # If the profile `access` is `:rpa`, then the `bot_driver` parameter is mandatory.
            
            #raise "The parameter `bot_driver` is mandatory." if bot_driver.nil? if self.profile_type.desc['access'].to_sym == :rpa
            # If the profile `access` is `:api`, then the `api_key` parameter is mandatory.
            #raise "The parameter `api_key` is mandatory." if api_key.nil? if self.profile_type.desc['access'].to_sym == :api
            # If the profile `access` is `:mta`, raise an exception.
            raise "The method `do` is not allowed for #{self.profile_type.desc['access'].to_s} access." if self.profile_type.desc['access'].to_sym == :mta
            # If the profile `access` is `:rpa`, then the `bot_url` parameter is mandatory, and it must be a valid URL.
            #raise "The parameter `bot_url` is mandatory." if bot_url.nil? if self.profile_type.desc['access'].to_sym == :rpa
            # If the profile `access` is `:api`, then the `api_params` parameter is mandatory and it must be a hash.
            #raise "The parameter `api_params` is mandatory." if api_params.nil? if self.profile_type.desc['access'].to_sym == :api
            # The `event_count` is for scrolling down (or perform any other required action) until finding `event_count` events.
            #raise "The parameter `event_count` must be an integer higher or equal then 0." if !event_count.is_a?(Integer) || event_count < 0

            # return
            return {
                'status' => :performed, # if it is not 'success', then it is an error description.
                'screenshots' => [
                    # array of URLs to screenshots
                ],
                # array of URLs to HTML snapshots
                'snapshot_url' => nil,
                'events' => [
                    # array of event descriptors
                ],
            }
        end # def do

    end # class Source
end # module Mass