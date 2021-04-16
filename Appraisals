{ '4.2' => '4.2.0', '5.0' => '5.0.0', '5.1' => '5.1.0', '6.0' => '6.0.0' }.each do |rails, version|
  appraise "rails-#{rails}" do
    gem "rails", "~> #{version}"
  end
end

appraise "rails-master" do
  gem "rails", github: "rails/rails"
end

