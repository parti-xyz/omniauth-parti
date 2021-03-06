require 'omniauth/strategies/parti'

describe OmniAuth::Strategies::Parti do
  include_context 'auth_code'
  include_context 'client'
  include_context 'user'

  before :all do
    OpenIDConnect.debug!
  end

  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end

  let(:strategy_class) { Class.new OmniAuth::Strategies::Parti }

  describe 'default options' do
    subject { strategy_class.new app }
    it 'has correct issuer' do
      expect(subject.options.issuer).to eq('https://v1.api.auth.parti.xyz')
    end

    it 'has default name' do
      expect(subject.options.name).to eq('parti')
    end

    it 'uses discovery' do
      expect(subject.options.discovery).to be true
    end

    it 'has default scope' do
      expect(subject.options.scope).to contain_exactly(:email, :openid)
    end

    it 'skips info' do
      expect(subject.options.skip_info).to be true
    end

    it 'has code response type' do
      expect(subject.options.response_type).to eq('code')
    end

    it 'has empty redirect uri' do
      expect(subject.options.client_options.redirect_uri).to eq(nil)
    end

    it 'has empty client id' do
      expect(subject.options.client_options.identifier).to eq(nil)
    end

    it 'has empty client secret' do
      expect(subject.options.client_options.secret).to eq(nil)
    end
  end

  describe 'settable options' do
    it 'sets issuer' do
      subject = strategy_class.new app, issuer: 'http://another-issuer.com'
      expect(subject.options.issuer).to eq('http://another-issuer.com')
    end

    it 'sets redirect uri' do
      subject = strategy_class.new app, client_options: { redirect_uri: 'http://redirect-uri.com' }
      expect(subject.options.client_options.redirect_uri).to eq('http://redirect-uri.com')
    end

    it 'sets client id' do
      subject = strategy_class.new app, client_options: { identifier: 'client-identifier' }
      expect(subject.options.client_options.identifier).to eq('client-identifier')
    end

    it 'sets client secret' do
      subject = strategy_class.new app, client_options: { secret: 'client-secret' }
      expect(subject.options.client_options.secret).to eq('client-secret')
    end
  end

  describe 'request phase', e2e: true do
    it 'redirects to authorization endpoint' do
      subject = strategy_class.new app,
        issuer: 'http://v1.api.auth.parti.xyz',
        client_options: {
          identifier: 'client-identifier',
          redirect_uri: 'http://redirect-uri.com'
        }

      expect(subject).to receive(:redirect) do |redirect_url|
        url = URI.parse redirect_url
        params = Hash[URI.decode_www_form(url.query)]

        expect(url.host).to eq('auth.parti.xyz')
        expect(params.keys).to contain_exactly(
          'client_id', 'nonce', 'redirect_uri', 'response_type', 'scope', 'state'
        )
        expect(params['client_id']).to eq('client-identifier')
        expect(params['nonce'].length).to be > 0
        expect(params['redirect_uri']).to eq('http://redirect-uri.com')
        expect(params['response_type']).to eq('code')
        expect(params['scope'].split).to contain_exactly('email', 'openid')
        expect(params['state'].length).to be > 0
      end
      subject.request_phase
    end
  end

  describe 'callback phase', e2e: true  do
    it 'build auth_hash' do
      client = client_exists
      user = user_exists

      subject = strategy_class.new app,
        issuer: 'http://v1.api.auth.parti.xyz',
        client_options: {
          identifier: client[:client_id],
          redirect_uri: client[:redirect_uris].first,
          secret: client[:client_secret]
        }

      auth_code = auth_code_is_issued(
        account: { parti: { identifier: user[:identifier] }},
        client_id: client[:client_id],
        client_secret: client[:client_secret],
        nonce: 'random-nonce',
        redirect_uri: client[:redirect_uris].first,
        scopes: ['openid']
      )

      allow(subject).to receive(:request) do
        double 'Request',
          params: {'code' => auth_code[:code], 'state' => 'random-state'},
          path_info: ''
      end

      subject.call!({'rack.session' => {'omniauth.state' => 'random-state', 'omniauth.nonce' => 'random-nonce'}})
      subject.callback_phase

      auth_hash = subject.auth_hash
      id_token = auth_hash.credentials.id_token
      id_info = OpenIDConnect::ResponseObject::IdToken.decode(id_token, subject.public_key)
      expect(id_info.iss).to eq('http://v1.api.auth.parti.xyz')
      expect(id_info.sub).to eq(auth_code[:account][:identifier])
      expect(id_info.aud).to eq(client[:client_id])
      expect(auth_hash.uid).to eq(auth_code[:account][:identifier])
    end
  end
end
