require_relative '../lib/mass-client'
require 'pry'

Mass.set(
    # mandatory parameters
    api_key: '4cb865f4-fa4f-4c2f-8456-d366de44e13a',
    subaccount: 'ConnectionSphere',
    # connect to development environment
    api_url: 'http://127.0.0.1', 
    api_port: 3000,
    # optional parameters
    backtrace: true,
)

Mass::Lead.upsert({
    'first_name' => 'Leandro',
    'last_name' => 'Sardi',
    'middle_name' => 'Daniel',
    #'picture_url' => 'https://media.licdn.com/dms/image/D4D03AQFKseTSZnpIAg/profile-displayphoto-shrink_100_100/0/1697551355295?e=1722470400&v=beta&t=2NZ4wUN2Cd9uzOuY0nrhWZOukpP84s3FPRFHNwOAZOs',
    'job_title' => 'Founder & CEO',
    'country' => 'Argentina',
    'timezone' => 'America/Argentina/Buenos_Aires',
    'email' => 'leandro@connectionsphere.com',
    'facebook' => 'https://www.facebook.com/leandro.sardi',
    'linkedin' => 'https://www.linkedin.com/in/leandro-daniel-sardi/',
    'tags' => ['testing'],
})
