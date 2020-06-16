Pod::Spec.new do |spec|
  spec.name         = "GECoreDataManager"
  spec.version      = "1.0.0"
  spec.summary      = "Simple and easy to use Core Data Manager"
  spec.description  = <<-DESC
                    CoreDataManager is a simple and easy to use manager class, designed to reduce the need of boilerplate coding when using iOS Core Data persistance. Based on NSPersistentContainer.
                   DESC
  spec.homepage     = "https://github.com"
  spec.license      = { :type => "MIT", :file => "LICENSE" }
  spec.author       = { "Guillem Espejo" => "g.espejogarcia@gmail.com" }
  spec.platform     = :ios, "13.0"
  spec.source       = { :git => "https://github.com/GuillemEspejo/CoreDataManager.git", :tag => "#{spec.version}" }
  spec.source_files = "CoreDataManager/Source/*.{swift}"
  spec.swift_version = "5.0"
end
