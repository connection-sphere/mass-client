NODENAME = 'n01'

# Setup parameters to connect your ConnectionSphere API
BlackStack::API.set_client(
    api_key: '<place your ConnectionSphere API Key here>',
    api_url: BlackStack.sandbox? ? 'http://127.0.0.1' : 'https://' + NODENAME + '.connectionsphere.com',
    api_port: BlackStack.sandbox? ? 3000 : 443,
    api_version: '1.0'
)
