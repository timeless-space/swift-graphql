Pod::Spec.new do |spec|
  spec.name         = 'SwiftGraphQL'
  spec.homepage     = 'https://swift-graphql.com'
  spec.authors      = { 'Matic Zavadlal' => 'matic.zavadlal@gmail.com' }
  spec.summary      = 'GraphQL query generator and client for Swift'
  spec.license      = { :type => 'MIT' }

  spec.version      = '4.1.0'
  spec.source       = { 
		:git => 'https://github.com/timeless-space/swift-graphql.git', 
		:tag => spec.version.to_s 
	}

  spec.source_files  = "Sources/**/*.swift"

  spec.dependency "Logging", "~> 1.4"
  spec.dependency "Starscream", "~> 4.0.0"
end
