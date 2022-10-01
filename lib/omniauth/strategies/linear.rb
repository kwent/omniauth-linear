require 'omniauth-oauth2'
require 'graphlient'

module OmniAuth
  module Strategies
    class Linear < OmniAuth::Strategies::OAuth2
      option :client_options, {
        site: 'https://api.linear.app/graphql',
        authorize_url: 'https://linear.app/oauth/authorize',
        token_url: 'https://api.linear.app/oauth/token',
        response_type: 'code',
      }

      option :auth_token_params, {
        grant_type: 'authorization_code',
      }

      def request_phase
        super
      end

      def authorize_params
        super.tap do |params|
          %w[client_options].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end
        end
      end

      uid { me.viewer.id }

      extra do
        { raw_info: raw_info, me: me.viewer }
      end

      def raw_info
        @raw_info ||= {}
      end

      def me
        @me ||= begin
          http = GraphQL::Client::HTTP.new(options.client_options.site) do |obj|
            def headers(context)
              {"Authorization" => "Bearer #{context[:token]}"}
            end
          end
          schema = GraphQL::Client.load_schema(http)
          client = GraphQL::Client.new(schema: schema, execute: http)
          client.allow_dynamic_queries = true
          client

          gql = client.query <<~GRAPHQL
            query {
              viewer {
                id
                name
                email
              }
            }
          GRAPHQL
          response = client.query(gql, context: {token: access_token.token})
          response.data
        end
      end

      def callback_url
        full_host + script_name + callback_path
      end
    end
  end
end

OmniAuth.config.add_camelization 'linear', 'Linear'