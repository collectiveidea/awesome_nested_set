{
  "5_2" => "5.2.0",
  "6_0" => "6.0.0",
  "6_1" => "6.1.0",
  "7_0" => "7.0.0",
  "7_1" => "7.1.0",
  "7_2" => "7.2.0"
}.each do |rails, version|
  appraise "rails-#{rails}" do
    gem "rails", "~> #{version}"
  end
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: "main"
  gem "rspec-rails", "~> 6.1"
end
