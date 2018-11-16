--[[加强型的require，建议项目中全部使用该方式加载lua文件，该文件的优势:
    1.能优先加载缓存中的lua文件
    2.不破坏当前所有代码结构
    3.方便使用
]]
zc = zc or {}
--[[
    这里最好给缓存文件夹一个特殊一点的名称，最好不要叫 res、src之类的，因为有些第三方的sdk也可能会在
    fileUtils:getWritablePath()创建类似res的文件夹。
    所以一般我在项目中，会以 .gameName 的形式创建缓存目录

    使用方法：
     requires("src/network/http/ZCHttp.lua")

     它将去依次寻找缓存，直到找到文件：
        fileUtils:getWritablePath() .. "src/network/http/ZCHttp.lua.luac" 
        fileUtils:getWritablePath() .. "src/network/http/ZCHttp.lua.lua" 
        fileUtils:getWritablePath() .. "src/network/http/ZCHttp.luac" 
        fileUtils:getWritablePath() .. "src/network/http/ZCHttp.lua" 
        "src/network/http/ZCHttp.lua"
]]
local cacheFolderName = ".cache"
function requires(filename)
    local path = nil
    local fileUtils = cc.FileUtils:getInstance()
    local writablePath = fileUtils:getWritablePath() .. cacheFolderName .."/";
    --如果是路径
    if fileUtils:isAbsolutePath(filename) then
        path = filename
    else
        local tmp = writablePath..filename
        if fileUtils:isFileExist(tmp..".luac") then
            path = tmp..".luac"
        elseif fileUtils:isFileExist(tmp..".lua") then
            path = tmp..".lua"
        elseif fileUtils:isFileExist(tmp.."c") then
            path = tmp.."c"
        elseif fileUtils:isFileExist(tmp) then
            path = tmp
        else
            path = filename
        end
    end
    return require(path)
end