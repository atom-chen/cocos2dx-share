--  Created by zcgit on 16-04-21.
--[[
http网络请求模块.
1.异步请求
2.能设置请求的回调函数
3.网络失败需要提示，且能支持重新请求
]]
--游戏请求地址
-- debug

ZCHttp = class("ZCHttp")

--[[loading的类型]]
HTTP_LOADING_TYPE = {
    CIRCLE  = 0,
    NONE    = 1
}
--请求的方式，默认全部是GET
HTTP_REQUEST_TYPE = {
    GET = 0,
    POST = 1
}

HTTP_ENCRYPT_TYPE = {
    AES = "aes",
    NONE = "none"
}


local function _getMethod(method)
    local _method = "GET"
    if method == HTTP_REQUEST_TYPE.POST then
        _method = "POST"
    end
    return _method
end

function ZCHttp:ctor(params)
end

--创建http
function ZCHttp:createWithParams(params)
    local http = ZCHttp.new(params)
    return http
end


--[[
异步请求网络
@url                     请求的网络地址(完整地址)
@method                  HTTP_REQUEST_TYPE.POST / HTTP_REQUEST_TYPE.GET
@startCallback           请求开始时的回调函数
@successCallback         请求成功的回调
@failedCallback          请求失败的回调
@targetNeedsToRetain     
@postData  
@loadingType             
@loadingNode             loading界面 
@loadingParent           loading界面所在的父容器
@reconnectTimes          网络请求失败后重新连接的次数(0不重新链接)
]]
function ZCHttp:requestAsyncWithParams(params)
    print("ZCHttp:requestAsyncWithParams")
    local url                 = tostring(params.url)--[[请求的网络地址(完整地址)]]
    local method              = params.method --[[请求的方式]]
    local startCallback       = params.startCallback--[[开始请求时的回调函数]]
    local successCallback     = params.successCallback--[[请求成功的回调函数]]
    local failedCallback      = params.failedCallback--[[请求失败的回调函数(此处的失败一般是指网络超时或者服务器返回的数据无法解析成json)]]
    local targetNeedsToRetain = params.targetNeedsToRetain--[[请求时需要被retain的对象]]
    local postData            = params.postData--[[post请求时需要的数据]]
    local loadingType         = params.loadingType --[[]]
    local targetNode          = params.targetNode--[[用于在网络返回时判断是否还需要处理数据的标记，如果标记不存在了，则不需要处理网络数据并且也无需提示网络不好]]
    local loadingNode         = params.loadingNode
    local loadingParent       = params.loadingParent
    local reconnectTimes      = params.reconnectTimes --[[如果网络失败，重新连接的次数(0或nil代表不需要重试)]]
    local timeoutForRead      = params.timeoutForRead 
    local timeoutForConnect   = params.timeoutForConnect 
    local encrypt             = params.encrypt 
    local responseType        = params.responseType
    local showLog             = params.showLog
    local header              = params.header or {}
    

    if nil == loadingType       then loadingType = HTTP_LOADING_TYPE.CIRCLE     end
    if nil == method            then method = HTTP_REQUEST_TYPE.GET            end
    if nil == reconnectTimes    then reconnectTimes = 0                         end
    if nil == timeoutForRead    then timeoutForRead = 10                        end
    if nil == timeoutForConnect then timeoutForConnect = 10                     end
    if nil == responseType      then responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON     end
    if nil == encrypt           then encrypt = HTTP_ENCRYPT_TYPE.NONE            end
    if nil == showLog           then showLog = true                             end


    local runningScene   = cc.Director:getInstance():getRunningScene()
    local _loadingNode   = loadingNode
    local _loadingParent = loadingParent
    if _loadingParent == nil then _loadingParent = runningScene end
    --加载loading层
    if _loadingNode == nil then
        if loadingType == HTTP_LOADING_TYPE.CIRCLE   then _loadingNode = LoadingCircleLayer:create()
        elseif loadingType == HTTP_LOADING_TYPE.NONE then end
    end
    --[[移除loading页面]]
    if _loadingNode ~= nil and _loadingParent~= nil then
        print("开始添加loading页面")
        _loadingParent:addChild(_loadingNode, 1000)
    end
    local _doRequest = nil
    local shouldResponseData = function ( ... )
        local flag = true
        if targetNode ~= nil and tolua.isnull(targetNode) == true then
            print("tolua.isnull(targetNode) == true")
            flag = false
        end
        return flag
    end
    local _failedCallback = function()
        --如果有失败的回调，则需要执行该回调
        if reconnectTimes > 0 then
            reconnectTimes = reconnectTimes - 1
            print("网络请求失败，正在重新连接...重新连接次数还剩下:"..reconnectTimes)
            _doRequest()
        else
            if not tolua.isnull(_loadingNode) then _loadingNode:removeFromParent() end
            if (shouldResponseData() == true) and failedCallback then failedCallback() else print("网络访问出错，但是没有failedCallback提示，建议加上该参数！") end
        end
    end
    local _url = url
    _doRequest = function()
        print("开始创建网络请求")
        if not tolua.isnull(targetNeedsToRetain) then targetNeedsToRetain:retain() end
        local xhr               = cc.XMLHttpRequest:new()
        xhr.timeoutForConnect   = timeoutForConnect
        xhr.timeoutForRead      = timeoutForRead
        -- cc.XMLHTTPREQUEST_RESPONSE_STRING       = 0
        -- cc.XMLHTTPREQUEST_RESPONSE_ARRAY_BUFFER = 1
        -- cc.XMLHTTPREQUEST_RESPONSE_BLOB         = 2
        -- cc.XMLHTTPREQUEST_RESPONSE_DOCUMENT     = 3
        -- cc.XMLHTTPREQUEST_RESPONSE_JSON         = 4
        xhr.responseType        = cc.XMLHTTPREQUEST_RESPONSE_STRING
        --[[在所有请求中加入渠道参数，方便后端做数据统计]]
        local doLog = function ( msg )
            if showLog == true then print(msg) end
        end
        doLog("ZCHttp-url="..tostring(_url).."-------"..tostring(postData))
        xhr:open(_getMethod(method), _url)
        local function onReadyStateChanged()
            if not tolua.isnull(targetNeedsToRetain) then targetNeedsToRetain:release() end
            xhr:unregisterScriptHandler()
            local response = xhr.response
            doLog("url="..tostring(_url).."--------ZCHTTP_response onReadyStateChanged: "..response)
            print("xhr.readyState : "..xhr.readyState..",xhr.status="..xhr.status)
            --[[4:DONE ]]
            if xhr.readyState == 4 and xhr.status == 200 then
                local parseJsonFailedCallback = function(msg)
                    zc.logE(msg)
                    print("网络请求失败，原因是：解析数据出错")
                end
                local data = nil
                local function xpcall_callback()
                    if responseType == cc.XMLHTTPREQUEST_RESPONSE_JSON then
                        -- base64
                        if encrypt == HTTP_ENCRYPT_TYPE.AES then
                            local responseDecode = ""
                            local len = string.len(response)
                            local step = math.ceil(len / 4)
                            for i = 1, 4 do
                                local p2 = len - step * (i - 1)
                                local p = step * i * -1
                                responseDecode = responseDecode .. string.sub(response, p, p2)
                            end
                            response = crypto.decodeBase64(responseDecode)
                        end
                        data = json.decode(response)
                    else
                        data = response
                    end
                end
                xpcall(xpcall_callback, parseJsonFailedCallback)
                if data then
                    if not tolua.isnull(_loadingNode) then 
                        _loadingNode:removeFromParent() 
                        print("移除loading页面")
                    end
                    if (shouldResponseData() == true) and successCallback then
                        successCallback(data,url)
                    end
                else
                    print("服务器返回出错，无法解析成json---data为空data为空data为空data为空data为空")
                    _failedCallback()
                end
            else
                print("网络请求失败，原因是：网络问题或者服务器返回状态码不对")
                _failedCallback()
            end
        end
        xhr:registerScriptHandler(onReadyStateChanged)
        for k,v in pairs(header) do
            print("header-k="..k..",v="..v)
            xhr:setRequestHeader(k, v)
        end
        xhr:send(postData)
    end
    _doRequest()
end

