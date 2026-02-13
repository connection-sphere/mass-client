Gem::Specification.new do |s|
    s.name        = 'mass-client'
    s.version     = '1.0.40'
    s.date        = '2026-02-05'
    s.summary     = "Ruby library for ConnectionSphere API."
    s.description = "Ruby library for ConnectionSphere API."
    s.authors     = ["Leandro Daniel Sardi"]
    s.email       = 'leandro@connectionsphere.com'
    s.files       = [
      'lib/base-line/ai_agent.rb',
      'lib/base-line/channel.rb',
      'lib/base-line/company.rb',
      'lib/base-line/connectioncheck.rb',
      'lib/base-line/data_type.rb',
      'lib/base-line/enrichment.rb',
      'lib/base-line/enrichment_type.rb',
      'lib/base-line/event.rb',
      'lib/base-line/headcount.rb',
      'lib/base-line/inboxcheck.rb',
      'lib/base-line/industry.rb',
      'lib/base-line/job.rb',
      'lib/base-line/lead.rb',
      'lib/base-line/location.rb',
      'lib/base-line/outreach.rb',
      'lib/base-line/unsubscribe.rb',
      'lib/base-line/outreach_type.rb',
      'lib/base-line/profile.rb',
      'lib/base-line/profile_type.rb',
      'lib/base-line/request.rb',
      'lib/base-line/revenue.rb',
      'lib/base-line/rule.rb',
      'lib/base-line/source.rb',
      'lib/base-line/source_type.rb',
      'lib/base-line/tag.rb',
      'lib/first-line/profile_api.rb',
      'lib/first-line/profile_mta.rb',
      'lib/first-line/profile_rpa.rb',
      'lib/mass-client.rb',
    ]
    s.homepage    = 'https://github.com/connection-sphere/mass-client'
    s.license     = 'MIT'
    s.add_runtime_dependency 'timeout', '~> 0.4.1'
    s.add_runtime_dependency 'base64', '~> 0.2.0'
    s.add_runtime_dependency 'uri', '~> 0.11.2'
    s.add_runtime_dependency 'net-http', '~> 0.2.0'
    s.add_runtime_dependency 'json', '~> 2.6.3'
    s.add_runtime_dependency 'blackstack-core', '~> 1.2.32'
    s.add_runtime_dependency 'colorize', '~>0.8.1'
    s.add_runtime_dependency 'simple_cloud_logging', '~> 1.2.6'
    s.add_runtime_dependency 'simple_command_line_parser', '~> 1.1.2'
    s.add_runtime_dependency 'adspower-client', '~> 1.0.19'
    s.add_runtime_dependency 'aws-sdk-s3', '~> 1.169.0'
    s.add_runtime_dependency 'mini_magick', '~> 5.1.0'
end