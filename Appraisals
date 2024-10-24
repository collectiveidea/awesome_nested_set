{
  "5_2" => "5.2.0",
  "6_0" => "6.0.0",
  "6_1" => "6.1.0",
  "7_0" => "7.0.0",
  "7_1" => "7.1.0",
  "7_2" => "7.2.0",
  "8_0" => "8.0.0.rc1"
}.each do |rails, version|
  appraise "rails-#{rails}" do
    gem "rails", "~> #{version}"
    if rails == "7_0"
      gem "base64"
      gem "bigdecimal"
      gem "drb"
      gem "mutex_m"
    end
  end
end

appraise "rails-main" do
  gem "rails", github: "rails/rails", branch: "main"
end
