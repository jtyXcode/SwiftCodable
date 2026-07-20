Pod::Spec.new do |spec|
  spec.name                  = "SwiftCodable"
  spec.version               = "0.1.1"
  spec.summary               = "Safe Codable property wrappers with defaults and lossy conversion."
  spec.description           = <<-DESC
    SwiftCodable provides property wrappers for missing, null and mismatched JSON
    values, including common defaults, optional values, nested Codable models and
    user-defined defaults.
  DESC
  spec.homepage              = "https://github.com/jtyXcode/SwiftCodable"
  spec.license               = { :type => "MIT", :file => "LICENSE" }
  spec.author                = "Yuantao"
  spec.source                = {
    :git => "https://github.com/jtyXcode/SwiftCodable.git",
    :tag => spec.version.to_s
  }
  spec.swift_versions        = ["5.6", "5.7", "5.8", "5.9", "5.10", "6.0"]
  spec.ios.deployment_target = "12.0"
  spec.source_files          = "Sources/SwiftCodable/**/*.swift"
  spec.resource_bundles      = {
    "SwiftCodable_Privacy" => [
      "Sources/SwiftCodable/Resources/PrivacyInfo.xcprivacy"
    ]
  }
  spec.framework             = "Foundation"
end
