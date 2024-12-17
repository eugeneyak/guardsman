require "digest/sha256"
require "openssl/hmac"
require "base64"

require "uri"

struct Profile
  getter id         : String
  getter first_name : String
  getter last_name  : String | Nil
  getter username   : String | Nil
  getter photo_url  : String | Nil
  
  getter auth_date  : String
  getter hash       : String

  def initialize(params : URI::Params)
    @id         = params["id"]
    @first_name = params["first_name"]
    @last_name  = params["last_name"]?
    @username   = params["username"]?
    @photo_url  = params["photo_url"]?
    @auth_date  = params["auth_date"]
    @hash       = params["hash"]
  end

  def initialize(encoded : String)
    params = Base64.decode_string(encoded)
    
    initialize URI::Params.parse(params)
  end

  def encode
    params = URI::Params.new

    params["id"] = id
    params["first_name"] = first_name
    params["auth_date"] = auth_date
    params["hash"] = hash

    params["last_name"] = last_name.as String if last_name
    params["username"]  = username.as  String if username
    params["photo_url"] = photo_url.as String if photo_url

    Base64.strict_encode(params.to_s)
  end
end

struct Profile::Validator
  getter key : Slice(UInt8)

  def initialize(token : String)
    @key = Digest::SHA256.new.update(token).final
  end

  def validate(profile : Profile)
    dcs = String.build do |io|
      io         << "auth_date="  << profile.auth_date
      io << "\n" << "first_name=" << profile.first_name
      io << "\n" << "id="         << profile.id
      io << "\n" << "last_name="  << profile.last_name.as(String) if profile.last_name
      io << "\n" << "photo_url="  << profile.photo_url.as(String) if profile.photo_url
      io << "\n" << "username="   << profile.username.as(String)  if profile.username
    end

    OpenSSL::HMAC.hexdigest(OpenSSL::Algorithm::SHA256, key, dcs) == profile.hash
  end
end