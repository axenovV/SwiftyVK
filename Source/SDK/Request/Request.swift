import Foundation



internal var sharedCaptchaIsRun = false
internal var sharedCaptchaAnswer : [String : String]?
internal var nextRequestId = 0
private func getNextRequestId() -> Int {
  nextRequestId += 1
  return nextRequestId
}


///Request to VK API
public class Request : CustomStringConvertible {
  internal let id : Int = getNextRequestId()
  public var timeout = VK.defaults.timeOut
  public var isAsynchronous = VK.defaults.sendAsynchronous
  ///Maximum number of attempts to send, after which execution priryvaetsya and an error is returned
  public var maxAttempts = VK.defaults.maxAttempts
  ///Whether to allow automatic processing of some API error
  public var catchErrors = VK.defaults.catchErrors
  ///Log for this request life time
  public internal(set) var log = [String]()
  ///Allows print log messages to console
  public var allowLogToConsole : Bool = VK.defaults.allowLogToConsole
  internal var method = ""
  internal private(set) var isAPI = false
  internal var attempts = 0
  internal var authFails = 0
  internal var canSend : Bool {return attempts < maxAttempts || maxAttempts == 0}
  internal var swappedRequest : Request? = nil
  internal var customURL : String? = nil
  public private(set) var cancelled = false
  private var useDefaultLanguage = VK.defaults.useSystemLanguage
  private var HTTPMethod = "GET"
  private var media : [Media]?
  private var parameters = [String : String]()
  public var successBlock : VK.SuccessBlock {
    get{return privateSuccessBlock}
    set{
      if swappedRequest != nil {swappedRequest?.successBlock = newValue}
      else {privateSuccessBlock = newValue}
    }
  }
  private var privateSuccessBlock = VK.defaults.successBlock {
    didSet {
      successBlockIsSet = true
      VK.Log.put(self, "Set new success block")
    }
  }
  public var errorBlock = VK.defaults.errorBlock {
    didSet {
      errorBlockIsSet = true
      VK.Log.put(self, "Set new error block")
    }
  }
  internal private(set) var successBlockIsSet = false
  internal private(set) var errorBlockIsSet = false
  public var progressBlock = VK.defaults.progressBlock
  public var language : String? {
    get {
      return useDefaultLanguage
      ? VK.defaults.language
      : privateLanguage
    }
    set {
      guard newValue == nil || VK.defaults.supportedLanguages.contains(newValue!) else {return}
      self.privateLanguage = newValue
      useDefaultLanguage = (newValue == nil)
    }
  }
  private var privateLanguage = VK.defaults.language
  internal var URLRequest : NSURLRequest {
    let req = NSURLFabric.get(url: customURL, HTTPMethod: HTTPMethod, method: method, params: allParameters, media: media)
    req.timeoutInterval = NSTimeInterval(self.timeout)
    VK.Log.put(self, "Create url: \(req.URL!.absoluteString) with timeout: \(timeout)")
    return req
  }
  internal lazy var response : Response = {
    let result = Response()
    result.request = self
    return result
  }()
  private var allParameters : [String : String] {
    var params = parameters
    
    if let token = Token.get() {
      params["access_token"] = token
    }
    
    if sharedCaptchaAnswer != nil {
      params["captcha_sid"] = sharedCaptchaAnswer!["captcha_sid"]
      params["captcha_key"] = sharedCaptchaAnswer!["captcha_key"]
      sharedCaptchaAnswer = nil
    }
    
    params["v"] = VK.defaults.apiVersion
    params["https"] = "1";
    
    if let lang = language {
      params["lang"] = lang
    }
    
    return params
  }
  public var description : String {
    get {return "Request: \(method) parameters: \(parameters), attempts: \(maxAttempts)"}
  }
  internal var answered = false

  
  
  
  internal init(url: String) {
    VK.Log.put(self, "INIT with custom url: \(url)")
    self.customURL = url
  }
  
  
  
  internal init(method: String, parameters: [VK.Arg : String] = [:]) {
    self.isAPI               = true
    self.method              = method
    self.parameters          = argToString(parameters)
    VK.Log.put(self, "INIT with method name: \(method) and parameters: \(self.parameters)")
  }
  
  
  
  internal init(url: String, media: [Media]) {
    self.maxAttempts         = 10
    self.HTTPMethod          = "POST"
    self.customURL           = url
    self.media               = media
    VK.Log.put(self, "INIT with media files: \(media)")
  }
  
  
  
  ///Add new parameters to request
  public func addParameters(agrDict: [VK.Arg : String]?) {
    for (argName, argValue) in agrDict! {
      VK.Log.put(self, "Add parameter: \(argName.rawValue)=\(argValue)")
      self.parameters[argName.rawValue] = argValue
    }
  }
  
  
  
  ///Send with blocks
  public func send(_successBlock: VK.SuccessBlock,_ _errorBlock:  VK.ErrorBlock) {
    self.successBlock = _successBlock
    self.errorBlock = _errorBlock
    self.send()
  }
  
  
  
  ///Just send
  public func send() {
    attempts = 0
    cancelled = false
    answered = false
    trySend()
  }
  
  
  
  internal func trySend() -> Bool {
    if canSend {
      attempts += 1
      let type = (self.isAsynchronous ? "asynchronously" : "synchronously")
      VK.Log.put(self, "Prepare to send \(type) \(attempts) of \(maxAttempts) times")
      response.clean()
      _ = Connection(request: self)
      return true
    }
    else {
      VK.Log.put(self, "Can no longer send! \(attempts) of \(maxAttempts) times")
      response.executeError()
      return false
    }
  }
  
  
  
  internal func tryInCurrentThread() -> Bool {
    if canSend {
      attempts += 1
      VK.Log.put(self, "Prepare to send \(attempts) of \(maxAttempts) times in current thread")
      response.clean()
      Connection.tryInCurrentThread(self)
      return true
    }
    else {
      VK.Log.put(self, "Can no longer send in current thread! \(attempts) of \(maxAttempts) times")
      response.executeError()
      return false
    }
  }
  
  
  
  public func cancel() {
    cancelled = true
    VK.Log.put(self, "Cancel")
  }
  
  
  
  private func argToString(agrDict: [VK.Arg : String]?) -> [String : String] {
    var strDict = [String : String]()
    
    guard agrDict != nil else {return [:]}
    
    for (argName, argValue) in agrDict! {
      strDict[argName.rawValue] = argValue
    }
    return strDict
  }
  
  
  
  init() {
    VK.Log.put(self, "INIT request")
  }
  
  
  
  deinit {
    VK.Log.put(self, "DEINIT request")
  }
}

