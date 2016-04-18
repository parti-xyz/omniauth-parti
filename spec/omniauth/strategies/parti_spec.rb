describe OmniAuth::Strategies::Parti do
  def app
    lambda do |_env|
      [200, {}, ["Hello."]]
    end
  end
  let(:strategy_class) { Class.new(OmniAuth::Strategies::Parti) }

  describe 'default options' do
    subject { strategy_class.new(app) }
    it 'has correct issuer' do
      expect(subject.options.issuer).to eq('https://v1.api.parti.xyz')
    end

    it 'has default name' do
      expect(subject.options.name).to eq('parti')
    end

    it 'uses discovery' do
      expect(subject.options.discovery).to be true
    end

    it 'has default scope' do
      expect(subject.options.scope).to eq([:openid])
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
end
